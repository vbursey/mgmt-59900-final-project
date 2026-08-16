# NYC Yellow Taxi: Urban Mobility & Revenue Efficiency Analytics

**Course:** MGMT 59900 - Big Data in the Cloud  
**Group:** 7 (Binny Bajaj, Michael Miranda, Vincent Hayes Bursey)  
**GitHub Repository:** [https://github.com/vbursey/mgmt-59900-final-project](https://github.com/vbursey/mgmt-59900-final-project)  

---

## Project Overview & Business Problem
Traditional taxi operations frequently judge operational success using gross revenue or total trip volume[cite: 3]. However, these aggregate metrics fail to highlight where passenger demand is concentrated, how efficiently specific zones generate revenue, or which routes contribute most heavily to top-line earnings[cite: 3].

This project analyzes **73+ million NYC Yellow Taxi trip records** spanning Q1 2015 and Q1 2016 to evaluate spatial-temporal demand patterns[cite: 3]. By calculating unit-level efficiency metrics—such as **revenue per mile** and **revenue per minute**—and identifying high-density corridors, this pipeline provides operations managers and drivers with empirical insights to optimize vehicle positioning and maximize hourly earning capacity[cite: 3].

---

## Key Empirical Findings & Business Insights

* **Overall Performance (Q1 2015 vs. Q1 2016):**
  * Analyzed **72,265,156 cleaned trips** generating **~$1.12 Billion in total revenue** with an average of **$15.47 revenue per trip**[cite: 3].
  * Q1 2016 trip volume declined by **10.55%** compared to Q1 2015, driven primarily by lower passenger demand across January, February, and March[cite: 3].
* **Pickup-Zone Demand vs. Revenue Efficiency:**
  * Passenger demand is heavily concentrated in Manhattan: **Upper East Side South** (2.65M trips) and **Midtown Center** (2.58M trips) were the highest-volume pickup zones[cite: 3].
  * *Crucial Takeaway:* High trip volume does **not** always correlate with high revenue per minute[cite: 3]. High-demand zones offer frequent fare opportunities but may suffer from traffic congestion, making dual evaluation of volume and time-based efficiency essential for vehicle positioning[cite: 3].
* **High-Revenue Travel Corridors:**
  * **LaGuardia Airport → Times Square/Theatre District** was the single highest-revenue route, generating **~$4.80 Million**[cite: 3].
  * Airport-to-Manhattan connections (JFK and LaGuardia to Midtown/Times Square) dominate top-revenue rankings in both directions[cite: 3].
  * Strong non-airport Manhattan corridors also emerged, such as **Upper East Side South ↔ Upper East Side North** (~$1.75M)[cite: 3].

---

## Serverless AWS Lakehouse Architecture

The pipeline implements an **AWS Data Lakehouse** following the **Medallion Architecture** pattern (Bronze → Silver → Gold)[cite: 3]. Redshift was eliminated in favor of an Athena-only serverless model, executing all validation, feature engineering, and dimensional aggregations via SQL CTAS queries[cite: 3].

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                     INGESTION LAYER                                    │
│  NYC TLC Public Parquet Files (Q1 2015 / Q1 2016)  +  NYC Taxi Zone Lookup (CSV)       │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              STORAGE LAYER (Amazon S3)                                 │
│  s3://mgmt-59900-final-project/                                                        │
│   ├── raw/    [Bronze Layer: Partitioned Raw Parquet & Reference Lookup Data]          │
│   ├── silver/ [Silver Layer: Cleaned Parquet Trips (72.2M Rows) + Derived Metrics]     │
│   └── gold/   [Gold Layer: Pre-Aggregated Monthly, Zone, and Route Performance]        │
└───────────────┬───────────────────────────▲────────────────────────────┬───────────────┘
                │                           │                            │
                │      Catalog Schemas      │    Execute CTAS / SQL      │
                ▼                           │                            ▼
┌───────────────────────────────────────────┴────────────────────────────────────────────┐
│                             CATALOG & PROCESSING LAYER                                 │
│  AWS Glue Data Catalog (Metadata Registry)  +  Amazon Athena (Serverless SQL)           │
└────────────────────────────────────────────────────────────────────────┬───────────────┘
                                                                         │
                                                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              OUTPUT & CONSUMPTION LAYER                                │
│  Amazon QuickSight (SPICE Dashboards)  +  Python / Jupyter Notebook Analysis           │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### AWS Services & Component Roles:
1. **Amazon S3:** Serves as the central durably partitioned storage layer (`year=YYYY/month=MM`) across Bronze, Silver, and Gold tiers[cite: 3].
2. **AWS Glue Data Catalog:** Acts as the centralized metadata registry storing schema definitions and partition locations across all Medallion tiers[cite: 3].
3. **Amazon Athena:** Executes serverless ANSI SQL for profiling, data cleaning (CTAS), feature engineering, and Gold table aggregations[cite: 3].
4. **Amazon QuickSight:** Ingests Gold-tier SPICE datasets to publish interactive visual dashboards without scanning raw underlying files[cite: 3].

---

## Medallion Pipeline Specifications

| Layer | Prefix Path | Format | Record Count | Description & Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Bronze** | `s3://mgmt-59900-final-project/raw/` | Parquet / CSV | 73,010,683[cite: 3] | Raw, immutable trip transaction records partitioned by `year` and `month`, alongside reference zone lookup tables[cite: 3]. |
| **Silver** | `s3://mgmt-59900-final-project/silver/` | Snappy-Parquet | 72,265,156[cite: 3] | Cleaned trip-level table (~99% data retention)[cite: 3]. Removes zero-distances, invalid fares, and duration anomalies[cite: 3]. Adds `trip_duration_min`, `revenue_per_mile`, and `revenue_per_minute`[cite: 3]. |
| **Gold** | `s3://mgmt-59900-final-project/gold/` | Snappy-Parquet | Pre-Aggregated[cite: 3] | Business-ready aggregated tables: `gold_monthly_performance`, `gold_zone_performance`, and `gold_route_performance`[cite: 3]. |

### Data Validation & Cleaning Rules applied at Silver Layer:
* **Trip Distance:** `0 < trip_distance <= 100` miles[cite: 3]
* **Financial Amounts:** `fare_amount >= 0` AND `0 < total_amount <= 500`[cite: 3]
* **Trip Duration:** Drop-off timestamp after pickup timestamp; `0 < duration <= 180` minutes[cite: 3]
* **Location Mapping:** Left join against `taxi_zone_lookup` to enrich numeric IDs with human-readable zone and borough names[cite: 3].

---

## Repository Setup & Query Execution Flow

### 1. Ingestion & Cataloging
* Land raw Parquet files into `s3://mgmt-59900-final-project/raw/yellow-taxi/year=YYYY/month=MM/`[cite: 3].
* Upload `taxi_zone_lookup.csv` into `s3://mgmt-59900-final-project/raw/reference/`[cite: 3].
* Run catalog DDL scripts in `sql/01_bronze_table_ddl.sql` to register raw tables in AWS Glue Data Catalog[cite: 3].

### 2. Data Quality & Silver CTAS Transformation
* Execute `sql/02_silver_cleaning_ctas.sql` in Amazon Athena to filter invalid records, cast schema types, calculate unit metrics, and output compressed Snappy-Parquet files into `silver/`[cite: 3].

### 3. Gold Analytical Aggregations
* Execute `sql/03_gold_aggregations_ctas.sql` to generate `gold_monthly_performance`, `gold_zone_performance`, and `gold_route_performance` tables[cite: 3].
* Connect Amazon QuickSight to Gold tables to power KPI cards, YoY trend lines, and route rankings[cite: 3].

---

## Cost Management & Governance Strategy

* **Total Project Execution Cost:** **< $1.00**[cite: 3].
* **Storage Optimization:** Raw Parquet files compression reduced ~73M rows into ~2–3 GB of storage (~$0.10/month)[cite: 3].
* **Athena Query Cost Controls:**
  * Enforced Hive partition clauses (`WHERE year = '2016' AND month = '01'`) during exploratory queries[cite: 3].
  * Pre-aggregated Gold tables eliminated repeated full-table scans of the 72.3M-row Silver dataset during QuickSight refreshes[cite: 3].
  * Configured active AWS Cost Budget alerts at a **$5.00 spend threshold**[cite: 3].

---

## Architecture Trade-Off: AWS Lakehouse vs. GCP Data Warehouse

| Evaluation Criteria | AWS Lakehouse (Athena + S3)[cite: 3] | GCP Data Warehouse (BigQuery + GCS)[cite: 3] |
| :--- | :--- | :--- |
| **Storage Openness** | **High Openness:** Open-standard Parquet files in S3 are directly accessible by Spark, Presto, Python, or external tools[cite: 3]. | **Moderate Lock-In:** Native BigQuery storage offers fast performance but requires explicit export operations for external engines[cite: 3]. |
| **Operational Maintenance** | **Higher Overhead:** Requires manual partition repairs (`MSCK REPAIR TABLE`), explicit DDL schema casting, and file compaction management[cite: 3]. | **Zero-Ops:** Automatically handles background file compaction, partitioning metadata, and schema enforcement[cite: 3]. |
| **Query Scaling** | **Variable Latency:** Performs exceptionally well on partitioned/compacted datasets; complex joins across 72M+ rows can experience metadata overhead[cite: 3]. | **Superior / Low Latency:** Native columnar storage and dynamic slot allocation deliver faster aggregations on un-optimized ad-hoc queries[cite: 3]. |
| **Cost Predictability** | **Granular Control ($< $1.00 Total):** Partition pruning and pre-aggregated Gold tables strictly cap scanned bytes[cite: 3]. | **Potential Scan Runaways:** Higher base query rates ($6.25/TB) and automated parallel slot allocation can trigger cost spikes during exploratory queries[cite: 3]. |

---

## Limitations & Future Improvements

### Current Limitations:
1. **Absence of Operating Cost Data:** The dataset lacks driver operating expenses (fuel, vehicle maintenance, insurance, and labor rates), restricting metrics to gross revenue efficiency rather than net profitability[cite: 3].
2. **Lack of Direct Idle & Repositioning Identifiers:** Meter-on to meter-off trip records do not explicitly track driver wait time, empty repositioning miles, or vehicle availability between trips[cite: 3].
3. **Low-Volume Outliers:** Single-trip or low-sample zones (e.g., specific Staten Island locations) can skew unit-efficiency metrics like revenue per minute without minimum volume thresholds[cite: 3].
4. **Time Scope Limitation:** Data covers Q1 2015 and Q1 2016, omitting seasonal trends in Q2–Q4 (e.g., summer travel patterns, holiday spikes)[cite: 3].

### Future Improvements:
* Expand ingestion pipelines across full 12-month datasets to capture annual seasonality[cite: 3].
* Integrate secondary external data sources (e.g., NOAA weather APIs, MTA subway status feeds) to model demand shifts during adverse weather or transit delays[cite: 3].

---

## Repository Directory Structure

```text
mgmt-59900-final-project/
│
├── README.md                          # Comprehensive project documentation
├── .gitignore                         # Ignores local checkpoints and data files
├── LICENSE                            # MIT License
│
├── architecture/                      # Architecture diagrams
│   └── aws_lakehouse_architecture.png # Complete S3-Athena-QuickSight workflow
│
├── sql/                               # Production SQL scripts
│   ├── 01_bronze_table_ddl.sql        # Glue Data Catalog table registration DDLs
│   ├── 02_silver_cleaning_ctas.sql    # Data quality profiling & Silver CTAS queries
│   └── 03_gold_aggregations_ctas.sql  # Monthly, Zone, and Route aggregation CTAS queries
│
│
├── screenshots/                       # Implementation evidence
│   ├── figure1_s3_raw_partitioning.png
│   ├── figure2_athena_partition_query.png
│   ├── figure3_athena_profiling_results.png
│   ├── figure4_silver_validation.png
│   ├── figure5_gold_zone_top10.png
│   └── figure6_quicksight_dashboard.png
│
└── docs/                              # Project documentation
    ├── project_proposal.pdf
    └── final_project_report_group7.pdf
```

---

## Generative AI Disclosure
Generative AI tools (including LLMs) were utilized throughout this project for technical brainstorming, SQL CTAS query optimization, AWS architecture troubleshooting, and documentation editing[cite: 3]. All AI-generated suggestions, code scripts, mathematical calculations, and analytical conclusions were independently audited, executed, and verified by the team prior to submission[cite: 3].
