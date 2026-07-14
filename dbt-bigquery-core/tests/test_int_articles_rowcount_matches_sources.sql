-- Custom test to ensure the union in int_newsapi__articles didn't drop or
-- duplicate rows from either staging source. Returns the mismatch when the
-- combined row count differs from the sum of both staging tables.

WITH source_counts AS (
    SELECT
        (SELECT COUNT(*) FROM {{ ref('stg_newsapi__articles_us_en') }})
        + (SELECT COUNT(*) FROM {{ ref('stg_newsapi__articles_de_de') }}) AS expected_count,
        (SELECT COUNT(*) FROM {{ ref('int_newsapi__articles') }}) AS actual_count
)

SELECT *
FROM source_counts
WHERE actual_count != expected_count
