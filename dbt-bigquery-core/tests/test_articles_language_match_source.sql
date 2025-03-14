-- Custom test to ensure language_code matches source_table
-- This test will fail if any row has a mismatch between language_code and source_table

WITH validation AS (
    SELECT
        *,
        CASE 
            WHEN source_table = 'us_en' AND language_code = 'en' THEN TRUE
            WHEN source_table = 'de_de' AND language_code = 'de' THEN TRUE
            ELSE FALSE
        END AS is_valid
    FROM {{ ref('int_newsapi__articles') }}
)

SELECT *
FROM validation
WHERE NOT is_valid 