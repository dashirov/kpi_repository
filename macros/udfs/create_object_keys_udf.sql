{% macro create_object_keys_udf(model_relation) %}
{#
  Expects:
    - model_relation: A dbt relation object (e.g. {{ this }})
      used to extract the target database and schema.
#}
{% set database = model_relation.database %}
{% set schema = model_relation.schema %}
{% set sql %}
CREATE OR REPLACE FUNCTION {{ database }}.{{ schema }}.OBJECT_KEYS(V VARIANT)
    returns VARIANT
    language JAVASCRIPT
    as
    $$
       return Object.keys(V).sort();
    $$;
{% endset %}
{{ run_query(sql) }}
{{ return("") }}
{% endmacro %}