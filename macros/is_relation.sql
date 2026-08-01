{% macro is_relation(obj) %}
    {#- True when obj is a dbt Relation — the shape ref() returns at execute
        time. Used by kpi__repository to validate consumer-supplied
        `kpi_repository_models` entries before unioning them in. Same
        predicate dbt_utils applies internally (see dbt_utils._is_relation). -#}
    {{ return(obj is mapping and obj.get('metadata', {}).get('type', '').endswith('Relation')) }}
{% endmacro %}
