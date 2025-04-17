{{
    config(
        snowflake_warehouse=set_warehouse('L'),
        materialized='incremental',
        incremental_strategy='delete+insert',
        alias='kpi__performance_report',
        unique_key='id',
        transient=false,
        query_tag={
            'cost-center': 'analytics',
            'data-product': 'kpi_collection_and_storage'
        },
        pre_hook = [
            "{{ create_object_keys_udf(this) }}",
            "{{ create_object_values_udf(this) }}",
            "{{ create_kpi_display_name_udf(this) }}"
        ] if is_airflow_dev() or is_dev() else []
    )
}}

{%- set backfill_mode = var('backfill', False) %}
{%- set reporting_period = var('reporting_period', 'week') -%}
{%- set anchor_date = var('anchor_date', dbt_utils.pretty_time(format='%Y-%m-%d')) -%}
{% set aop_relation = ref('kpi__aop_targets') %}
{% set aop_exists = (adapter.get_relation(
    database=aop_relation.database,
    schema=aop_relation.schema,
    identifier=aop_relation.identifier
) is not none) %}
{% if aop_exists %}
    {{ log("AOP Targets table exists: examining the data type of the DIMENSIONS column", info=True) }}
    {%- set columns = adapter.get_columns_in_relation(aop_relation) -%}
    {%- set aop_dimensions_datatype = (columns | selectattr("name", "equalto", "DIMENSIONS") | first).data_type -%}
{% else %}
    {{ log("AOP Targets table does exist in this environment: assuming the data type of the DIMENSIONS column is VARCHAR", info=True) }}
    {%- set aop_dimensions_datatype = 'VARCHAR' -%}
{% endif %}

WITH
    current_measurements AS (
        SELECT
            id
            , indicator
            , cycle
            , cycle_timestamp
            , dimensions
            , value
        FROM {{ ref('kpi__repository') }}
        {%- if is_incremental() and backfill_mode == False %}
            WHERE
                cycle = '{{ reporting_period }}'
                AND cycle_timestamp
                = {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')") }}
                - {{ interval(reporting_period) }}
        {%- endif %}
    )

    , prior_measurements AS (
        SELECT
            id
            , indicator
            , cycle
            , cycle_timestamp
            , dimensions
            , value
        FROM {{ ref('kpi__repository') }}
        {%- if is_incremental() and backfill_mode == False %}
            WHERE
                cycle = '{{ reporting_period }}'
                {%- if reporting_period in ['week','bi-week'] -%}
                    AND EXTRACT(YEAR FROM cycle_timestamp) = EXTRACT(
                        YEAR FROM (
                            {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')" ) }}
                            - {{ interval(reporting_period) }}
                        )
                    ) - 1
                    AND EXTRACT(WEEK FROM cycle_timestamp) = EXTRACT(
                        WEEK FROM (
                            {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')" ) }}
                            - {{ interval(reporting_period) }}
                        )
                    )
                {%- else -%}
                    AND cycle_timestamp
                        = {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')" ) }}
                          - {{ interval(reporting_period) }}
                          - interval '1 year'
                {%- endif %}
        {%- endif %}
    )

    , aop AS (
        SELECT
            cycle_timestamp
            , plan
            , indicator,
            {%- if aop_dimensions_datatype != 'VARIANT' -%}
                
                
                PARSE_JSON(dimensions) AS dimensions
            {%- else -%}
        DIMENSIONS
        {%- endif %},
            cycle
        FROM {{ ref('kpi__aop_targets') }}
        WHERE
            cycle = '{{ reporting_period }}'
            AND cycle_timestamp
            = {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')") }}
            - {{ interval(reporting_period) }}
    )

    , measurements_with_prior AS (
        SELECT
            cm.id
            , cm.indicator
            , cm.cycle
            , cm.cycle_timestamp
            , cm.dimensions
            , cm.value AS current_value
            , pm.value AS prior_value
            , aop.plan AS aop_value
            , ROW_NUMBER() OVER (
                PARTITION BY
                    cm.indicator
                    , cm.dimensions
                    , cm.cycle
                    , cm.cycle_timestamp
                ORDER BY
                    pm.cycle_timestamp DESC
            ) AS rn
        FROM current_measurements AS cm
        LEFT JOIN aop USING (cycle_timestamp, cycle, indicator, dimensions)
        LEFT JOIN prior_measurements AS pm
            ON (
                cm.indicator = pm.indicator
                AND cm.dimensions = pm.dimensions
                AND cm.cycle = pm.cycle
                AND (
                    (
                        cm.cycle IN ('day', 'month', 'quarter', 'year')
                        AND cm.cycle_timestamp - INTERVAL '1 year' = pm.cycle_timestamp
                    )
                    OR
                    (
                        cm.cycle IN ('week', 'bi-week')
                        AND EXTRACT(YEAR FROM cm.cycle_timestamp)
                        = EXTRACT(YEAR FROM pm.cycle_timestamp) + 1
                        AND EXTRACT(WEEK FROM cm.cycle_timestamp)
                        = EXTRACT(WEEK FROM pm.cycle_timestamp)
                    )
                )
            )
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY
                cm.indicator
                , cm.dimensions
                , cm.cycle
                , cm.cycle_timestamp
            ORDER BY
                pm.cycle_timestamp DESC
        ) = 1
    )

SELECT
    measurements_with_prior.id
    , measurements_with_prior.indicator
    , measurements_with_prior.cycle
    , measurements_with_prior.cycle_timestamp
    , measurements_with_prior.dimensions
    , CONCAT_WS(
        ' '
        , measurements_with_prior.indicator
        , 'by'
        , COALESCE(
            NULLIF(
                ARRAY_TO_STRING(
                    {{ this.database }}.{{ this.schema }}.object_keys(measurements_with_prior.dimensions)
                    , ' x '
                )
                , ''
            )
            , '*'
        )
    ) AS metric
    , {{ this.database }}.{{ this.schema }}.kpi_display_name(
        bg.readable_indicator, measurements_with_prior.dimensions
    ) AS metric_display_name
    , COALESCE(
        ARRAY_TO_STRING(
            {{ this.database }}.{{ this.schema }}.object_values(measurements_with_prior.dimensions)
            , ','
        )
        , ''
    ) AS coordinates
    , (
        CASE measurements_with_prior.cycle
            WHEN 'day' THEN 0
            WHEN 'week' THEN 1
            WHEN 'bi-week' THEN 2
            WHEN 'month' THEN 3
            WHEN 'quarter' THEN 4
            WHEN 'year' THEN 5
        END
    )::NUMERIC * POW(10, 10)
    + TO_CHAR(measurements_with_prior.cycle_timestamp, 'yyyymmddHH24')::NUMERIC AS sortkey
    , CASE measurements_with_prior.cycle
        WHEN 'year' THEN 'Y-' || DATE_PART('year', measurements_with_prior.cycle_timestamp)
        WHEN 'month' THEN TO_CHAR(measurements_with_prior.cycle_timestamp, 'yyyy-Mon')
        WHEN 'week' THEN 'W-' || DATE_PART('week', measurements_with_prior.cycle_timestamp)
        WHEN 'quarter' THEN
            DATE_PART('year', measurements_with_prior.cycle_timestamp)
            || 'Q'
            || DATE_PART('quarter', measurements_with_prior.cycle_timestamp)
    END AS "LABEL"
    , measurements_with_prior.current_value
    , measurements_with_prior.prior_value
    , measurements_with_prior.aop_value
    , {{ dbt_utils.generate_surrogate_key([
         'indicator',
         'metric',
         'coordinates',
         'cycle',
         'cycle_timestamp'
    ]) }} AS alt_id
FROM measurements_with_prior
INNER JOIN {{ ref('kpi__business_glossary') }} AS bg
    USING (indicator)
WHERE measurements_with_prior.rn = 1
