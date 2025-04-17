{% macro create_kpi_display_name_udf(model_relation) %}
{#
  Expects:
    - model_relation: A dbt relation object (e.g., `{{ this }}`) from which the database and schema are extracted.
#}
{% set database = model_relation.database %}
{% set schema = model_relation.schema %}
  {% set sql %}
      CREATE OR REPLACE FUNCTION {{ database }}.{{ schema }}.KPI_DISPLAY_NAME(INDICATOR STRING, DIMENSIONS VARIANT)
            RETURNS STRING
            LANGUAGE JAVASCRIPT
          AS
      $$
            if (DIMENSIONS === null || typeof DIMENSIONS !== 'object') {
              return INDICATOR + ' - Global';
            }
            let keys = Object.keys(DIMENSIONS).sort();
            let values = keys.map(key => DIMENSIONS[key]);
            let joinedValues = values.join(', ');
            let dimensionStr = (joinedValues.trim() === '') ? 'Global' : joinedValues;
            return INDICATOR + ' - ' + dimensionStr;
      $$;
  {% endset %}
  {{ run_query(sql) }}
  {{ return("") }}
{% endmacro %}