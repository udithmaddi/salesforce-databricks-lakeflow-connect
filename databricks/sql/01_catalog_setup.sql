-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 1: Catalog Setup
-- MAGIC **Project:** AI-Powered Sales Insights (Salesforce + Databricks)
-- MAGIC
-- MAGIC **Goal:** create one catalog `crm_poc` with three schemas (one per data layer).
-- MAGIC
-- MAGIC | Level | Name | Purpose |
-- MAGIC | --- | --- | --- |
-- MAGIC | Catalog | `crm_poc` | Main folder for this project |
-- MAGIC | Schema | `bronze` | Raw Salesforce data |
-- MAGIC | Schema | `silver` | Cleaned data with quality flags |
-- MAGIC | Schema | `gold` | Business-ready tables |

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Create the catalog
-- MAGIC Creates `crm_poc` only if it does not already exist.
-- MAGIC
-- MAGIC If you get *"storage location required"*, use:
-- MAGIC `CREATE CATALOG IF NOT EXISTS crm_poc MANAGED LOCATION '<your-path>';`

-- COMMAND ----------

CREATE CATALOG IF NOT EXISTS crm_poc
COMMENT 'POC: Salesforce CRM data integration using Lakeflow Connect';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Use the catalog
-- MAGIC Sets `crm_poc` as the default catalog for this session.

-- COMMAND ----------

USE CATALOG crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Create the three schemas
-- MAGIC Bronze (raw), Silver (cleaned), Gold (business-ready).

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS crm_poc.bronze COMMENT 'Raw Salesforce data';
CREATE SCHEMA IF NOT EXISTS crm_poc.silver COMMENT 'Cleaned data with quality flags';
CREATE SCHEMA IF NOT EXISTS crm_poc.gold   COMMENT 'Business-ready tables';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Show the schemas
-- MAGIC **Expected:** `bronze`, `silver`, `gold` (plus `default` and `information_schema`, added by Databricks).

-- COMMAND ----------

SHOW SCHEMAS IN crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Describe the catalog
-- MAGIC Confirms the catalog name, owner and comment.

-- COMMAND ----------

DESCRIBE CATALOG EXTENDED crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Done
-- MAGIC - [x] Catalog `crm_poc` created
-- MAGIC - [x] Schemas `bronze`, `silver`, `gold` created
-- MAGIC
-- MAGIC **Next:** Step 3, connect Databricks to Salesforce.