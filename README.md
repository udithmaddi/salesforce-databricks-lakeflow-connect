# AI-Powered Sales Insights: Salesforce + Databricks Lakeflow Connect

End-to-end proof of concept: Salesforce data is loaded into Databricks with Lakeflow Connect (Bronze), cleaned and quality-checked (Silver), turned into business tables (Gold), and served through an AI/BI dashboard and a Genie space. A Salesforce data generator and a daily Databricks job keep everything refreshing automatically.

![Architecture](docs/architecture_diagram.png)

Full documentation: [docs/Overview.md](docs/Overview.md)

## Daily flow (India Standard Time)

| Time | What happens |
| --- | --- |
| 5:00 AM | Salesforce Apex generator creates new, updated and deleted records (good and bad) |
| 7:00 AM | Databricks job `crm_poc_salesforce_ingestion job`: ingestion pipeline (incremental load into Bronze), then `check_bronze`, `build_silver`, `build_gold` |
| 8:00 AM | Published dashboard refreshes. Genie reads the Gold tables live |

## Screenshots

**Dashboard.** The published AI/BI dashboard is exported as a PDF: [dashboard/Sales_Insights_CRM_POC_DASHBOARD.pdf](dashboard/Sales_Insights_CRM_POC_DASHBOARD.pdf).

**Salesforce and data loading** (the dataloader.io screenshots have the login name hidden):

| | |
| --- | --- |
| ![Salesforce Seller Home](screenshots/01_salesforce_seller_home.png) | ![dataloader.io New Task menu](screenshots/02_dataloader_new_task_menu.png) |
| Salesforce Seller Home after the daily generator has run | dataloader.io: **New Task** menu (Import, Export, Delete) |
| ![dataloader.io Insert dialog](screenshots/03_dataloader_insert_connection_object.png) | ![dataloader.io task results](screenshots/04_dataloader_task_results.png) |
| dataloader.io: Insert, step 1 (connection, operation, object) | dataloader.io: task list with 60 / 152 / 200 / 250 successes and 0 errors |

## Repository layout

```
.
├── README.md
├── data/
│   ├── Accounts.csv
│   ├── Contacts.csv
│   ├── Leads.csv
│   └── Opportunities.csv
├── salesforce/
│   ├── CrmPocDataGenerator.cls
│   └── schedule_data_generator.apex
├── databricks/
│   ├── sql/
│   │   ├── 01_catalog_setup.sql
│   │   ├── 02_check_connection.sql
│   │   ├── 03_check_bronze_gate.sql
│   │   ├── 04_silver_cleaning_and_quality.sql
│   │   └── 05_gold_tables_and_ai_scoring.sql
│   ├── pipeline/
│   │   └── bronze_ingestion_pipeline.json
│   └── job/
│       └── daily_job_definition.json
├── dashboard/
│   ├── Sales_Insights_CRM_POC.lvdash.json
│   ├── Sales_Insights_CRM_POC_DASHBOARD.pdf
│   └── dashboard_datasets.sql
├── genie/
│   ├── genie_general_instructions.txt
│   └── genie_space_setup.md
├── screenshots/
│   ├── 01_salesforce_seller_home.png
│   ├── 02_dataloader_new_task_menu.png
│   ├── 03_dataloader_insert_connection_object.png
│   └── 04_dataloader_task_results.png
└── docs/
    ├── Overview.md
    ├── architecture_diagram.png
    └── architecture_diagram.svg
```

| Folder | Contents |
| --- | --- |
| `data/` | Sample CSV files loaded into Salesforce (Accounts, Contacts, Leads, Opportunities) |
| `salesforce/` | Apex class `CrmPocDataGenerator` (daily data generator) and its schedule lines |
| `databricks/sql/` | Notebooks in run order: `01` catalog, `02` connection check, `03` Bronze check and gate, `04` Silver, `05` Gold |
| `databricks/pipeline/` | Optional ingestion pipeline definition |
| `databricks/job/` | Optional job definition (placeholders to fill in) |
| `dashboard/` | Importable AI/BI dashboard, its eight dataset queries, and a PDF export of the published dashboard |
| `genie/` | Genie instructions and the full space setup (sources, questions, example SQL, tests) |
| `screenshots/` | Salesforce Seller Home and dataloader.io screenshots |
| `docs/` | Overview document and architecture diagram |

## How to use

1. Load the four CSV files from `data/` into a Salesforce Developer Edition org (Step 1 in the overview).
2. In Databricks run `01_catalog_setup.sql`, create the Salesforce connection, then run `02_check_connection.sql`.
3. Create the ingestion pipeline into `crm_poc.bronze` (Step 4) and run it once by hand as a full load.
4. Import and run `04_silver_cleaning_and_quality.sql`, then `05_gold_tables_and_ai_scoring.sql`.
5. Import `dashboard/Sales_Insights_CRM_POC.lvdash.json`, publish it, and schedule its refresh for 8:00 AM.
6. Create the Genie space using the files in `genie/`.
7. Install `salesforce/CrmPocDataGenerator.cls` in Salesforce and schedule it for 5:00 AM.
8. Add the tasks `check_bronze` (`03_check_bronze_gate`), `build_silver` and `build_gold` to the daily job, in that order, and schedule it for 7:00 AM.

The SQL notebook numbers are the run order. The step numbers in the overview are different.

## Notes

- No credentials are stored in this repository. The Salesforce login lives in a Unity Catalog connection (OAuth).
- Catalog, schema, job and object names are in the overview under "Naming reference".
- `databricks/job/daily_job_definition.json` contains placeholders (`<PIPELINE_ID>`, `<your-email>`). Fill them in before using it.
- The end-to-end test queries are in the overview, Step 10.
- Salesforce Developer Edition has about 5 MB of data storage. Delete the scheduled generator job when the demo ends.
