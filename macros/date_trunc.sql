{%- macro date_trunc(period, date_expr) -%}
{#
    This macro replaces the standard snowflake date_trunc. In addition to snowflake-supported  date and time parts,
    this function offers an additional date part: `bi-week`. Bi-Week date part truncates a date to the nearest odd ISO
    week starting date.
#}
{%- if period == 'bi-week' -%}
DATEADD(
      'week',
      CASE
        WHEN MOD(EXTRACT(WEEKISO FROM DATE_TRUNC('week', {{ date_expr }})), 2) = 0 THEN -1
        ELSE 0
      END,
      DATE_TRUNC('week', {{ date_expr }})
    )
  {%- else -%}
    DATE_TRUNC('{{ period }}', {{ date_expr }})
  {%- endif -%}
{%- endmacro -%}