with source as (
      select * from {{ source('newsapi', 'raw_newsapi__articles_de_de') }}
)
select * from source
  