{% macro test_json_key_accepted_values(model, column_name, key, accepted_values=[], accepted_relation=None, accepted_column=None) %}
  {% if accepted_relation is not none and accepted_column is not none %}
    {% if accepted_values | length > 0 %}
      {#-- Build a static list of accepted values --#}
      {% set static_values = [] %}
      {% for value in accepted_values %}
        {% set escaped_value = "'" ~ value.replace("'", "''") ~ "'" %}
        {% do static_values.append(escaped_value) %}
      {% endfor %}
      SELECT *
      FROM {{ model }}
      WHERE
        {{ column_name }}:{{ key }} IS NOT NULL
        AND {{ column_name }}:{{ key }} NOT IN (
          SELECT {{ accepted_column }} FROM {{ accepted_relation }}
          UNION
          SELECT column1 FROM VALUES ({{ static_values | join('), (') }}) AS t(column1)
        )
    {% else %}
      {#-- Only use the values from the relation --#}
      SELECT *
      FROM {{ model }}
      WHERE
        {{ column_name }}:{{ key }} IS NOT NULL
        AND {{ column_name }}:{{ key }} NOT IN (
          SELECT {{ accepted_column }} FROM {{ accepted_relation }}
        )
    {% endif %}
  {% else %}
    {#-- Fallback to the static list logic --#}
    {% set static_values = [] %}
    {% for value in accepted_values %}
      {% set escaped_value = "'" ~ value.replace("'", "''") ~ "'" %}
      {% do static_values.append(escaped_value) %}
    {% endfor %}
    SELECT *
    FROM {{ model }}
    WHERE
      {{ column_name }}:{{ key }} IS NOT NULL
      AND {{ column_name }}:{{ key }} NOT IN ({{ static_values | join(', ') }})
  {% endif %}
{% endmacro %}