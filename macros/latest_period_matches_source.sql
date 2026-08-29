{% test latest_period_matches_source(model, source_model, column_name) %}
with model_max as (
    select max({{ column_name }}) as max_mesdatper
    from {{ model }}
),
source_max as (
    select max({{ column_name }}) as max_mesdatper
    from {{ ref(source_model) }}
)
select *
from model_max
cross join source_max
where coalesce(model_max.max_mesdatper, -1) != coalesce(source_max.max_mesdatper, -1)
{% endtest %}
