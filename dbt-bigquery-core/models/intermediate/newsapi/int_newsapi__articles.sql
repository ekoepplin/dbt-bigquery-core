-- Intermediate model to join US English and German articles
WITH us_en_articles AS (
    SELECT 
        source_name,
        author,
        title,
        description,
        url,
        image_url,
        published_at,
        content,
        language_code,
        _dlt_load_id,
        _dlt_id
    FROM {{ ref('stg_newsapi__articles_us_en') }}
),

de_de_articles AS (
    SELECT 
        source_name,
        author,
        title,
        description,
        url,
        image_url,
        published_at,
        content,
        language_code,
        _dlt_load_id,
        _dlt_id
    FROM {{ ref('stg_newsapi__articles_de_de') }}
)

-- Union the two article sources
SELECT 
    source_name,
    author,
    title,
    description,
    url,
    image_url,
    published_at,
    content,
    language_code,
    _dlt_load_id,
    _dlt_id,
    'us_en' AS source_table
FROM us_en_articles

UNION ALL

SELECT 
    source_name,
    author,
    title,
    description,
    url,
    image_url,
    published_at,
    content,
    language_code,
    _dlt_load_id,
    _dlt_id,
    'de_de' AS source_table
FROM de_de_articles 