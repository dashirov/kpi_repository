{% test assert_values_in_other_model(model, column_name, values_model, values_column_name) %}

{%- if kwargs.get('hint') %}
/* Hint: {{ kwargs.get('hint') }} */
{%- endif %}
with invalid_values as (

    select
        {{ model }}.{{ column_name }} as invalid_value
    from {{ model }}
             left join {{ ref(values_model) }} as acceptable_values
                       on {{ model }}.{{ column_name }} = acceptable_values.{{ values_column_name }}
    where acceptable_values.{{ values_column_name }} is null

)

select * from invalid_values

{% endtest %}