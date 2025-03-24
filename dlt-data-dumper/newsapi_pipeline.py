import argparse
from datetime import datetime, timedelta
from pathlib import Path

import dlt
from loguru import logger  # Import Loguru
from newsapi.newsapi_client import NewsApiClient

# Get today's date and calculate the date range for a 24-hour period
today = datetime.utcnow().date()
before_yesterday = today - timedelta(days=2)

target_schema_name: str = dlt.config[f"{Path(__file__).stem}.destination.schema_name"]


# Define a resource for fetching articles from the US
@dlt.resource(table_name="articles_us_en", write_disposition="append")
def get_articles_us_en(api_key=dlt.secrets.value):
    logger.info("Fetching articles from the US (English)")
    newsapi = NewsApiClient(api_key=api_key)
    articles = newsapi.get_everything(
        language="en",
        q="Artificial Intelligence OR AI",
        from_param=before_yesterday.isoformat(),
        to=today.isoformat(),
        sort_by="publishedAt",
    )
    for article in articles["articles"]:
        yield article


# Define a resource for fetching articles from Germany
@dlt.resource(table_name="articles_de_de", write_disposition="append")
def get_articles_de_de(api_key=dlt.secrets.value):
    logger.info("Fetching articles from Germany (German)")
    newsapi = NewsApiClient(api_key=api_key)
    articles = newsapi.get_everything(
        language="de",
        q="Künstliche Intelligenz OR KI OR AI",
        from_param=before_yesterday.isoformat(),
        to=today.isoformat(),
        sort_by="publishedAt",
    )
    for article in articles["articles"]:
        yield article


@dlt.source
def run_all_articles():
    return (get_articles_us_en(), get_articles_de_de())


def run_pipeline(destination="filesystem", full_refresh=False):
    pipeline = dlt.pipeline(
        pipeline_name="newsapi_articles",
        destination=destination,
        dataset_name=target_schema_name,
    )

    load_info = pipeline.run(
        run_all_articles(), write_disposition="replace" if full_refresh else "append"
    )

    logger.info(f"Load info: {load_info}")
    logger.success(f"All data processed and uploaded to {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true", help="Enable test mode")
    parser.add_argument(
        "--full-refresh", action="store_true", help="Perform a full refresh"
    )
    parser.add_argument("--log-level", default="INFO", help="Set log level")
    args = parser.parse_args()

    logger.remove()
    logger.add(sink=lambda msg: print(msg, end=""), level=args.log_level)

    destination = "duckdb" if args.test else "bigquery"

    run_pipeline(destination=destination, full_refresh=args.full_refresh)
