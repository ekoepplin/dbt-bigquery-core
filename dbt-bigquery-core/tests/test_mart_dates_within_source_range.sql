-- Every article_date in the mart must fall within the date range of the
-- source intermediate model. Failures indicate the mart contains dates
-- that cannot be traced back to any source article (data integrity issue).
with mart as (
    select article_date
    from {{ ref('mart_newsapi__daily_articles') }}
),

source_range as (
    select
        cast(min(published_at) as date) as min_date,
        cast(max(published_at) as date) as max_date
    from {{ ref('int_newsapi__articles') }}
)

select mart.article_date
from mart, source_range
where
    mart.article_date < source_range.min_date
    or mart.article_date > source_range.max_date
