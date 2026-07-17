{% macro set_warehouse(size) %}
  {#-
    Optionally pick a per-model Snowflake warehouse by size code (e.g. 'S').
    Hello-world default: return none so dbt uses the warehouse from the active
    target/profile. A production deploy can map size codes to named warehouses.
  -#}
  {{ return(none) }}
{% endmacro %}
