-- Custom test to ensure no articles have a future publication date

SELECT *
FROM {{ ref('int_newsapi__articles') }}
WHERE published_at > CURRENT_DATE() 