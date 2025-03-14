-- Custom test to ensure we don't have the same article in multiple languages
-- This test checks for potential duplicates by comparing titles

WITH article_counts AS (
    SELECT
        title,
        COUNT(DISTINCT language_code) AS language_count
    FROM {{ ref('int_newsapi__articles') }}
    GROUP BY title
    HAVING COUNT(DISTINCT language_code) > 1
)

SELECT *
FROM article_counts 