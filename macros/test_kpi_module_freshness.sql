{% macro test_kpi_module_freshness(model, reporting_period) %}
{% set model_ref = model %}

-- Set anchor date to determine the last complete reporting cycle
{%- set anchor_date = var('anchor_date', dbt_utils.pretty_time(format='%Y-%m-%d')) %}

with
-- Calculate the start of the last complete reporting cycle in SQL
last_complete_cycle as (
    select
        {{ date_trunc(reporting_period, "to_date('" ~ anchor_date ~ "')") }}
        - {{ interval(reporting_period) }} as cycle_start
),

-- Get all unique combinations of INDICATOR and dimension strings from the model
unique_combinations as (
    select
        indicator,
        OBJECT_KEYS(DIMENSIONS) DIMENSIONS
    from {{ model_ref }}
    group by all
),

-- Get combinations that have data for the last complete reporting cycle
combinations_with_data as (
    select
        m.indicator,
        OBJECT_KEYS(DIMENSIONS) DIMENSIONS
    from {{ model_ref }} m
        cross join last_complete_cycle lcc
    where m.cycle = '{{ reporting_period }}'
      and m.cycle_timestamp = lcc.cycle_start
    group by all
),

-- Identify missing combinations
    missing_combinations as (
select
    u.indicator,
    u.dimensions
from unique_combinations u
    left join combinations_with_data c
        using(indicator,dimensions)
where c.indicator is null
    )

select * from missing_combinations


{% endmacro %}
