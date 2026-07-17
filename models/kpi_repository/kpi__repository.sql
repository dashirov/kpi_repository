{{
    config(
         snowflake_warehouse=set_warehouse('S')
       , materialized='incremental'
       , alias = 'kpi__repository'
       , unique_key='id'
       , query_tag = {'cost-center': 'analytics', 'data-product': 'kpi_collection_and_storage'}
    )
}}

{%- set anchor_date = var('anchor_date', dbt_utils.pretty_time(format='%Y-%m-%d')) %}
{%- set reporting_period = var('reporting_period','week') %}
{%- set backfill_mode = var('backfill', False) %}

{% set shadow_relation = ref('kpi__repository_shadow') %}
{% set shadow_exists = (adapter.get_relation(
    database=shadow_relation.database,
    schema=shadow_relation.schema,
    identifier=shadow_relation.identifier
) is not none) %}

{% set user_models = var('kpi_repository_models', []) %}
{% set required_columns = ['indicator', 'dimensions', 'cycle', 'cycle_timestamp', 'value', 'id'] %}

{#-
  Consumer models are optional. With none configured the repository still runs
  as a standalone "hello world": it materializes purely from the
  kpi__repository_shadow seed. When a consuming project sets
  `kpi_repository_models`, each is validated (at execute time, so parsing never
  touches the warehouse) and unioned in.
-#}
{% if execute %}
  {% for model_name in user_models %}
    {% set model_relation = ref(model_name) %}

    {% if not is_relation(model_relation) %}
      {% do exceptions.raise_compiler_error("The model '" ~ model_name ~ "' could not be resolved with ref(). Check if the model exists.") %}
    {% endif %}

    {% set model_columns = adapter.get_columns_in_relation(model_relation) %}
    {% set model_column_names = model_columns | map(attribute='name') | list %}

    {% for required_col in required_columns %}
      {% if required_col | lower not in model_column_names | map('lower') | list %}
        {% do exceptions.raise_compiler_error("The model '" ~ model_name ~ "' is missing required column '" ~ required_col ~ "'. It must have all columns: " ~ required_columns | join(', ')) %}
      {% endif %}
    {% endfor %}

  {% endfor %}
{% endif %}

with
{% if user_models %}
    DATA as (
        {{ dbt_utils.union_relations(
            relations = user_models,
            column_override={'VALUE':'NUMBER(18,4)', 'CYCLE_TIMESTAMP': 'TIMESTAMP_NTZ'},
            include=['ID', 'INDICATOR', 'CYCLE', 'DIMENSIONS','CYCLE_TIMESTAMP', 'VALUE']
            ) }}
    )
    ,
{% endif %}
    FINAL_DATASET AS (
        {% if shadow_exists %}

            {{ log("Shadow exists", info=True) }}

            SELECT
                cast(
                    '{{ ref('kpi__repository_shadow') }}' AS TEXT
                ) AS _DBT_SOURCE_RELATION
                , INDICATOR
                , parse_json(DIMENSIONS) AS DIMENSIONS
                , CYCLE
                , to_timestamp_ntz(CYCLE_TIMESTAMP) AS CYCLE_TIMESTAMP
                , to_numeric(VALUE) AS VALUE
                , ID
            FROM {{ ref('kpi__repository_shadow') }}
            {% if user_models %}
            UNION
            SELECT
                _DBT_SOURCE_RELATION
                , INDICATOR
                , DIMENSIONS
                , CYCLE
                , CYCLE_TIMESTAMP
                , VALUE
                , ID
            FROM DATA
            WHERE NOT EXISTS (
                SELECT 1
                FROM {{ ref('kpi_repository','kpi__repository_shadow') }} AS SHADOW
                WHERE
                    (DATA.ID = SHADOW.ID)
                    OR (
                        DATA.INDICATOR = SHADOW.INDICATOR
                        AND DATA.DIMENSIONS = parse_json(SHADOW.DIMENSIONS)
                        AND DATA.CYCLE = SHADOW.CYCLE
                        AND DATA.CYCLE_TIMESTAMP
                        = to_timestamp_ntz(SHADOW.CYCLE_TIMESTAMP)
                    )
            )
            {% endif %}
        {% elif user_models %}
            SELECT
                _DBT_SOURCE_RELATION
                , INDICATOR
                , DIMENSIONS
                , CYCLE
                , CYCLE_TIMESTAMP
                , VALUE
                , ID
            FROM DATA
        {% else %}
            {#- No shadow seed and no consumer models: emit an empty, correctly
                typed result so the model still builds. -#}
            SELECT
                cast(null AS TEXT) AS _DBT_SOURCE_RELATION
                , cast(null AS TEXT) AS INDICATOR
                , parse_json(null) AS DIMENSIONS
                , cast(null AS TEXT) AS CYCLE
                , cast(null AS TIMESTAMP_NTZ) AS CYCLE_TIMESTAMP
                , cast(null AS NUMBER(18,4)) AS VALUE
                , cast(null AS TEXT) AS ID
            WHERE 1 = 0
        {% endif %}
    )

SELECT *
FROM FINAL_DATASET
{% if is_incremental() and backfill_mode == False %}
    /* ONLY PREVIOUS COMPLETE {{ reporting_period }} */
    WHERE
        CYCLE = '{{ reporting_period }}'
        AND CYCLE_TIMESTAMP =
        {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')") }}
        - {{ interval(reporting_period) }}
{% endif %}
