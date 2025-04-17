{{
    config(
       snowflake_warehouse=set_warehouse('S')
       , materialized='incremental'
       , alias = 'kpi__owner'
       , unique_key=['effective_date','indicator']
       , query_tag = {'cost-center': 'analytics', 'data-product': 'kpi_collection_and_storage'}
    )
}}
SELECT
    DATE('2025-01-01') AS EFFECTIVE_DATE
    , INDICATOR
    , 'John Doe' AS OWNER
    , '' AS LEAD_ANALYST
    , 'Jane Doe' AS BI_PAL
FROM {{ ref('kpi__business_glossary') }}
WHERE
    CATEGORY = 'acquisition'
    AND IS_KPI = TRUE

UNION DISTINCT

SELECT
    DATE('2025-01-01') AS EFFECTIVE_DATE
    , INDICATOR
    , 'Jose Sanchez' AS OWNER
    , '' AS LEAD_ANALYST
    , 'Josephine Sanchez' AS BI_PAL
FROM {{ ref('kpi__business_glossary') }}
WHERE
    CATEGORY = 'conversion'
    AND IS_KPI = TRUE

UNION DISTINCT

SELECT
    DATE('2025-01-01') AS EFFECTIVE_DATE
    , INDICATOR
    , 'Ivan Petrov' AS OWNER
    , '' AS LEAD_ANALYST
    , 'Maria Petrova' AS BI_PAL
FROM {{ ref('kpi__business_glossary') }}
WHERE
    CATEGORY = 'engagement'
    AND IS_KPI = TRUE

