-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 2: Check the Salesforce connection
-- MAGIC Confirms `salesforce_lakeflow_poc_connection` exists.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. List connections
-- MAGIC **Expected:** a row named `salesforce_lakeflow_poc_connection` with type `SALESFORCE`.

-- COMMAND ----------

SHOW CONNECTIONS;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Describe the connection
-- MAGIC Shows owner, type and options. No password is displayed.

-- COMMAND ----------

DESCRIBE CONNECTION salesforce_lakeflow_poc_connection;