-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 4: Check the Bronze data
-- MAGIC Run this after the ingestion pipeline finishes successfully.
-- MAGIC In the daily job this is the task `check_bronze`: if a Bronze table is empty it fails, so Silver and Gold are skipped.

-- COMMAND ----------

USE CATALOG crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. List the tables
-- MAGIC **Expected:** `account`, `contact`, `lead`, `opportunity`

-- COMMAND ----------

SHOW TABLES IN bronze;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Row counts

-- COMMAND ----------

SELECT 'Account'     AS object, COUNT(*) AS bronze_rows FROM bronze.account
UNION ALL
SELECT 'Contact',     COUNT(*) FROM bronze.contact
UNION ALL
SELECT 'Lead',        COUNT(*) FROM bronze.lead
UNION ALL
SELECT 'Opportunity', COUNT(*) FROM bronze.opportunity;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Gate: every Bronze table must have rows
-- MAGIC Each cell fails with a clear message if its table is empty.

-- COMMAND ----------

SELECT assert_true(COUNT(*) > 0, 'bronze.account has no rows') AS account_ok FROM bronze.account;

-- COMMAND ----------

SELECT assert_true(COUNT(*) > 0, 'bronze.contact has no rows') AS contact_ok FROM bronze.contact;

-- COMMAND ----------

SELECT assert_true(COUNT(*) > 0, 'bronze.lead has no rows') AS lead_ok FROM bronze.lead;

-- COMMAND ----------

SELECT assert_true(COUNT(*) > 0, 'bronze.opportunity has no rows') AS opportunity_ok FROM bronze.opportunity;