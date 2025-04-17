{% macro create_object_values_udf(model_relation) %}
{#
  Expects:
    - model_relation: A dbt relation object (e.g. {{ this }})
      used to extract the target database and schema.
#}
{% set database = model_relation.database %}
{% set schema = model_relation.schema %}
{% set sql %}
CREATE OR REPLACE FUNCTION {{ database }}.{{ schema }}.OBJECT_VALUES(V VARIANT)
        returns VARIANT
        language JAVASCRIPT
    as
    $$
       let keys = Object.keys(V).sort();
       return keys.map(k => V[k]);
    $$;
{% endset %}
{{ run_query(sql) }}
{{ return("") }}
{% endmacro %}