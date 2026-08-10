# mgmt-59900-final-project
# NYC Yellow Taxi: Urban Mobility & Revenue Efficiency Analytics

**Course:** MGMT 59900 - Big Data in the Cloud  
**Group:** 7 (Binny Bajaj, Michael Miranda, Vincent Hayes Bursey)  

---

## Project Overview
Traditional taxi operations often evaluate performance using high-level metrics such as gross revenue or total trip volume. However, these aggregate numbers mask operational inefficiencies, including driver idle time, uncompensated vehicle repositioning, and supply-demand spatial imbalances.

This project leverages **73+ million NYC Yellow Taxi trip records** (Q1 2015 vs. Q1 2016) to analyze spatial-temporal demand patterns. By evaluating metrics like **revenue per mile**, **revenue per minute**, and **zone net flow**, our pipeline delivers actionable insights to help operations managers and drivers optimize vehicle positioning and maximize earning efficiency.

---

## Cloud Architecture (AWS Lakehouse)

The pipeline is built on an **AWS Data Lakehouse architecture** following the **Medallion Pattern** (Bronze → Silver → Gold):

```
[ NYC TLC Dataset (Parquet) ] ──┐
                               ├──> [ S3 Bronze (Raw) ] ──(Athena CTAS)──> [ S3 Silver (Cleaned) ] ──(Athena CTAS)──> [ S3 Gold (Aggregated) ]
[ Taxi Zone Lookup (CSV) ]   ──┘                                                                                             │
                                                                                                                             └──> [ QuickSight / Python BI ]
```

### AWS Services Utilized:
* **Amazon S3:** Centralized Data Lake storing Parquet objects partitioned by `Year` and `Month`.
* **AWS Glue Data Catalog:** Centralized metadata repository enforcing schema rules and tracking table partitions.
* **Amazon Athena:** Serverless ANSI SQL engine used for data profiling, CTAS data transformations, and analytical query execution.

---

## Medallion Data Pipeline & Dataset Details

* **Dataset:** NYC Yellow Taxi Trip Data (Jan–Mar 2015 & Jan–Mar 2016) + NYC Taxi Zone Lookup Table
* **Total Raw Records:** 73,010,683 rows
* **Cleaned Silver Records:** 72,265,156 rows (~99% retention rate)

| Layer | Prefix Path | Format | Description & Purpose |
| :--- | :--- | :--- | :--- |
| **Bronze** | `s3://mgmt-59900-final-project/raw/` | Parquet / CSV | Immutable raw trip files partitioned by `year` and `month`, plus reference lookup tables. |
| **Silver** | `s3://mgmt-59900-final-project/silver/` | Snappy-Parquet | Cleaned trip-level records. Removes negative fares, zero distances, and invalid durations. Adds calculated fields: `trip_duration_min`, `revenue_per_mile`, `revenue_per_minute`, `pickup_hour`, and `pickup_dow`. |
| **Gold** | `s3://mgmt-59900-final-project/gold/` | Snappy-Parquet | Pre-aggregated analytical tables (`gold_monthly_performance`, `gold_zone_performance`, `gold_route_performance`) for instant BI rendering. |

---

## Setup & Execution Steps

### 1. Storage & Ingestion
1. Upload raw historical trip Parquet files to `s3://mgmt-59900-final-project/raw/yellow-taxi/year=YYYY/month=MM/`.
2. Upload `taxi_zone_lookup.csv` to `s3://mgmt-59900-final-project/raw/reference/`.

### 2. Cataloging & Data Quality Profiling
1. Run Glue Crawlers or execute DDL statements in **Amazon Athena** to register the `yellow_taxi` raw table and `taxi_zone_lookup` table.
2. Execute data quality checks located in `sql/02_silver_cleaning_ctas.sql` to profile invalid records (e.g., negative fares, extreme durations).

### 3. Silver & Gold Layer Processing
1. Run the Silver CTAS query to write cleaned, feature-engineered Parquet files into the `silver/` prefix.
2. Run Gold aggregation CTAS queries (`sql/03_gold_aggregations_ctas.sql`) to construct business-ready tables.

---

## How to Interpret Analytical Results

### Key Performance Indicators (KPIs)
* **Revenue Per Mile ($/Mi):** Indicates route financial efficiency. Short trips with high airport surcharges or congested short-distance fares often yield higher $/Mi than long highway routes.
* **Revenue Per Minute ($/Min):** Measures time efficiency. Higher $/Min highlights peak earning windows where drivers experience minimal traffic delay.
* **Zone Net Flow ($\text{Pickups} - \text{Drop-offs}$):**
  * **Positive Net Flow (+):** High passenger demand / Cab deficit → **Target repositioning zone for drivers.**
  * **Negative Net Flow (-):** High cab accumulation / Low local demand → **Risk of driver idle time.**

---

## Repository Directory Structure

```text
├── architecture/      # AWS Lakehouse architecture diagrams
├── sql/               # SQL scripts for Bronze, Silver, Gold CTAS transformations
├── notebooks/         # Python / Colab exploratory data analysis and visualization notebooks
├── screenshots/       # AWS console implementation evidence (S3, Athena, QuickSight)
└── docs/              # Project proposal and technical write-ups
```

---

##` Cost Management & Governance
* **Active Controls:** Partition filtering (`WHERE year = '2016' AND month = '01'`) enforced on queries; AWS Budget alerts set at $5.00 thresholds.
* **Teardown Protocol:** All S3 objects, Glue catalog databases, and IAM execution roles are systematically deleted post-evaluation to ensure $0.00 ongoing cloud spend.
