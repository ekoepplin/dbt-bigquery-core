WITH daily_articles AS (
    SELECT
        CAST(published_at AS DATE) AS article_date,
        COUNT(*) AS article_count
    FROM {{ ref('int_newsapi__articles') }}
    WHERE published_at IS NOT NULL
    GROUP BY 1
)

SELECT 
    article_date,
    article_count
FROM daily_articles