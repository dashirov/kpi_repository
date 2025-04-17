{{
    config(
         snowflake_warehouse=set_warehouse('L')
       , materialized='incremental'
       , incremental_strategy='delete+insert'
       , alias = 'kpi__timeseries_analysis'
       , unique_key='id'
       , query_tag = {'cost-center': 'analytics', 'data-product': 'kpi_collection_and_storage'}
    )
}}

{%- set anchor_date = var('anchor_date', dbt_utils.pretty_time(format='%Y-%m-%d')) %}
{%- set reporting_period = var('reporting_period','week') %}
{%- set backfill_mode = var('backfill', False) %}

{%- set reporting_timeframes = { 'day':32, 'bi-week':6, 'week':8,  'month':13, 'quarter': 5, 'year': 3} -%}

WITH
    CALENDAR_SPINE AS (
        -- create a blank daily calendar that goes from yesterday's date back to beginning of 2018
        SELECT
            DATEADD(DAY, ROW_NUMBER() OVER (
                ORDER BY SEQ4()
            ) - 1, '2018-01-01'::date) AS CALENDAR_DATE
        FROM TABLE(GENERATOR(ROWCOUNT => 5000)) -- Adjust ROWCOUNT as needed
        QUALIFY CALENDAR_DATE <= CURRENT_DATE
    )

    , REPORTING_SPINE AS (
        -- for each reporting period (cycle) and every calendar date determine
        -- the period starting timestamp
        SELECT DISTINCT
            '{{ reporting_period }}' AS CYCLE
            , {{ date_trunc( reporting_period  ,'calendar_date') }} AS CYCLE_TIMESTAMP
        FROM CALENDAR_SPINE
    )

    , METRIC_SPINE AS (
        -- independently of the placeholders defined above, get a list of metrics
        -- defined by metric measure and metric coordinates (within a system of coordinates)
        SELECT DISTINCT
            INDICATOR
            , DIMENSIONS
        FROM {{ ref('kpi__performance_report') }}
    )

    , REPO AS (
        SELECT *
        FROM {{ ref('kpi__performance_report') }}
        WHERE
            CYCLE = '{{ reporting_period }}'
        {% if is_incremental() and backfill_mode == False %}
             AND CYCLE_TIMESTAMP <=
                  {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')") }}
                      - {{ interval(reporting_period) }}
            QUALIFY ROW_NUMBER() OVER(
                PARTITION BY CYCLE,INDICATOR,DIMENSIONS
                ORDER BY CYCLE_TIMESTAMP DESC
                ) <= 1 +  {{ reporting_timeframes.get(reporting_period) }} -- this and X previous data points
        {% endif %}

    )


    , CALCULATIONS AS (
        {% set historical_lookback = reporting_timeframes.get(reporting_period) %}
        /*
            PARTITION: {{ reporting_period }}
            NUMBER OF DATA POINTS REQUIRED TO ESTABLISH RELIABLE HISTORY: {{ historical_lookback }}
            */
        SELECT
           {{ dbt_utils.generate_surrogate_key([
              'indicator','dimensions','cycle','cycle_timestamp'
              ]) }} AS ID
            , INDICATOR
            , DIMENSIONS
            , CYCLE
            , CYCLE_TIMESTAMP
            , {{ dbt_utils.star(from=ref('kpi__performance_report'),
                            except=['id', "indicator", "dimensions", "cycle", "cycle_timestamp"],
                            relation_alias='REPO' ) }}
            , {{ historical_lookback }}::integer AS HISTORICAL_LOOKBACK
            , COUNT(REPO.CURRENT_VALUE) OVER (
                PARTITION BY INDICATOR, CYCLE, DIMENSIONS
                ORDER BY CYCLE_TIMESTAMP
                ROWS BETWEEN {{ historical_lookback }} PRECEDING AND 1 PRECEDING
            ) = HISTORICAL_LOOKBACK AS HAS_HISTORY
            , IFF(HAS_HISTORY, AVG(REPO.CURRENT_VALUE) OVER (
                PARTITION BY INDICATOR, CYCLE, DIMENSIONS
                ORDER BY CYCLE_TIMESTAMP
                ROWS BETWEEN {{ historical_lookback }} PRECEDING AND 1 PRECEDING
            ), NULL) AS MIDPOINT
            , IFF(HAS_HISTORY, STDDEV_SAMP(REPO.CURRENT_VALUE) OVER (
                PARTITION BY INDICATOR, CYCLE, DIMENSIONS
                ORDER BY CYCLE_TIMESTAMP
                ROWS BETWEEN {{ historical_lookback }} PRECEDING AND 1 PRECEDING
            ), NULL) AS SIGMA
            , MIDPOINT + 1.5 * SIGMA AS UPPER_BOUNDARY
            , MIDPOINT - 1.5 * SIGMA AS LOWER_BOUNDARY
            , REPO.CURRENT_VALUE NOT BETWEEN LOWER_BOUNDARY AND UPPER_BOUNDARY
                AS IN_ALERT
            , IFF(
                IN_ALERT, IFF(REPO.CURRENT_VALUE < LOWER_BOUNDARY, '↓', '↑'), NULL
            )
                AS ALERT
        FROM REPORTING_SPINE
        CROSS JOIN METRIC_SPINE
        LEFT OUTER JOIN REPO
            USING (INDICATOR, DIMENSIONS, CYCLE, CYCLE_TIMESTAMP)
    )

SELECT *
FROM CALCULATIONS
WHERE
    METRIC IS NOT NULL
{% if is_incremental() and backfill_mode == False %}
    /* ONLY PREVIOUS COMPLETE {{ reporting_period }} */
        AND CYCLE_TIMESTAMP =
        {{ date_trunc(reporting_period, "DATE('" ~ anchor_date ~ "')") }}
        - {{ interval(reporting_period) }}
    {% endif %}
