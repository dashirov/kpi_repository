{%- macro interval(period='bi-week') -%}
{%- if period == 'bi-week' -%}
INTERVAL '2 weeks'
  {%- else -%}
    INTERVAL {{  "'1 " ~ period ~ "'" }}
  {%- endif -%}
{%- endmacro -%}