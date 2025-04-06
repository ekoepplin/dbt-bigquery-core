WITH daily_articles AS (
    SELECT
        published_at AS article_date,
        COUNT(*) AS article_count
    FROM {{ ref('int_newsapi__articles') }}
    WHERE published_at IS NOT NULL
    GROUP BY 1  
)

SELECT 
    article_date,
    CAST(article_count AS STRING) AS article_count
FROM daily_articles