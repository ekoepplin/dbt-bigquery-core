-- Mart model for daily article trends
-- Tracks article volume over time by language

WITH daily_articles AS (
    SELECT
        EXTRACT(DATE FROM published_at) AS article_date,
        language_code,
        COUNT(*) AS article_count,
        COUNT(DISTINCT source_name) AS source_count
    FROM {{ ref('int_newsapi__articles') }}
    WHERE published_at IS NOT NULL
    GROUP BY EXTRACT(DATE FROM published_at), language_code
),

-- Calculate 7-day rolling averages
rolling_metrics AS (
    SELECT
        article_date,
        language_code,
        article_count,
        source_count,
        AVG(article_count) OVER (
            PARTITION BY language_code
            ORDER BY article_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7day_avg_articles,
        AVG(source_count) OVER (
            PARTITION BY language_code
            ORDER BY article_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7day_avg_sources
    FROM daily_articles
)

SELECT
    article_date,
    language_code,
    article_count,
    source_count,
    rolling_7day_avg_articles,
    rolling_7day_avg_sources,
    LAG(article_count) OVER (
        PARTITION BY language_code
        ORDER BY article_date
    ) AS prev_day_article_count,
    CASE 
        WHEN LAG(article_count) OVER (PARTITION BY language_code ORDER BY article_date) > 0
        THEN (article_count - LAG(article_count) OVER (PARTITION BY language_code ORDER BY article_date)) / 
             LAG(article_count) OVER (PARTITION BY language_code ORDER BY article_date)
        ELSE NULL
    END AS day_over_day_change
FROM rolling_metrics
ORDER BY article_date DESC, language_code 