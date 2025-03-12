with source as (
    select * from {{ source('newsapi', 'raw_newsapi__articles_us_en') }}
)

select * from source 