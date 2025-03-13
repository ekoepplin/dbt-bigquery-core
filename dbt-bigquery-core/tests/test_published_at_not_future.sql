-- Custom test to ensure no articles have a future publication date

SELECT *
FROM {{ ref('int_newsapi__articles_combined') }}
WHERE published_at > CURRENT_TIMESTAMP() 