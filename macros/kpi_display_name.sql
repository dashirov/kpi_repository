{% macro kpi_display_name(indicator, dimensions) %}
{#
  Expects:
    - indicator: A column reference or string literal representing the KPI indicator.
    - dimensions: A column reference to a variant object whose values will be concatenated.
#}
CONCAT_WS(
    ' - ',
    {{ indicator }},
    COALESCE(
      NULLIF(
        ARRAY_TO_STRING(
          OBJECT_VALUES({{ dimensions }}),
          ', '
        ),
        ''
      ),
      'Global'
    )
  )
{% endmacro %}