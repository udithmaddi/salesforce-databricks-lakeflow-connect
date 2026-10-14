-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 5: Silver, clean the data and check quality
-- MAGIC **Reads:** `crm_poc.bronze.*` (raw Salesforce data)
-- MAGIC **Writes:** `crm_poc.silver.*` and `crm_poc.gold.data_quality_checks`, `crm_poc.gold.data_quality_score`
-- MAGIC
-- MAGIC **What cleaning means here**
-- MAGIC 1. Keep only the columns we need
-- MAGIC 2. Give them clear lower_case names (`StageName` becomes `stage`)
-- MAGIC 3. Fix data types (`Amount` to decimal, `CloseDate` to date)
-- MAGIC 4. Trim spaces and standardise text (emails to lower case)
-- MAGIC 5. Add `is_valid` (TRUE if the row passed all rules) and `dq_reason` (why it failed)
-- MAGIC
-- MAGIC Bad rows are **flagged, not deleted**. Gold uses only rows where `is_valid = TRUE`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 0. Use the catalog

-- COMMAND ----------

USE CATALOG crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Silver account
-- MAGIC **Rules:** account name not empty, account name unique (case-insensitive).

-- COMMAND ----------

CREATE OR REPLACE TABLE silver.account AS
WITH base AS (
  SELECT
    Id                                   AS account_id,
    TRIM(Name)                           AS account_name,
    COALESCE(TRIM(Industry), 'Unknown')  AS industry,
    TRIM(BillingCity)                    AS city,
    TRIM(BillingState)                   AS state,
    TRIM(BillingCountry)                 AS country,
    CAST(NumberOfEmployees AS INT)       AS employees,
    CAST(AnnualRevenue AS DECIMAL(18,2)) AS annual_revenue,
    Phone                                AS phone,
    CAST(CreatedDate AS TIMESTAMP)       AS created_at,
    COUNT(*) OVER (PARTITION BY LOWER(TRIM(Name))) AS name_count
  FROM bronze.account
)
SELECT
  * EXCEPT (name_count),
  CASE
    WHEN account_name IS NULL OR account_name = '' THEN FALSE
    WHEN name_count > 1                            THEN FALSE
    ELSE TRUE
  END AS is_valid,
  CONCAT_WS('; ',
    CASE WHEN account_name IS NULL OR account_name = '' THEN 'missing account name' END,
    CASE WHEN name_count > 1 THEN 'duplicate account name' END
  ) AS dq_reason
FROM base;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Silver contact
-- MAGIC **Rules:** belongs to an account, email looks valid.

-- COMMAND ----------

CREATE OR REPLACE TABLE silver.contact AS
SELECT
  Id                                    AS contact_id,
  AccountId                             AS account_id,
  TRIM(FirstName)                       AS first_name,
  TRIM(LastName)                        AS last_name,
  CONCAT_WS(' ', TRIM(FirstName), TRIM(LastName)) AS full_name,
  TRIM(Title)                           AS title,
  LOWER(TRIM(Email))                    AS email,
  Phone                                 AS phone,
  TRIM(MailingCity)                     AS city,
  CAST(CreatedDate AS TIMESTAMP)        AS created_at,
  CASE
    WHEN AccountId IS NULL                       THEN FALSE
    WHEN Email IS NULL OR Email NOT RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN FALSE
    ELSE TRUE
  END AS is_valid,
  CONCAT_WS('; ',
    CASE WHEN AccountId IS NULL THEN 'contact without account' END,
    CASE WHEN Email IS NULL OR Email NOT RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN 'missing or invalid email' END
  ) AS dq_reason
FROM bronze.contact;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Silver lead
-- MAGIC **Rules:** company not empty, email looks valid.
-- MAGIC `is_converted` is TRUE if Salesforce converted the lead or its status is `Closed - Converted`.

-- COMMAND ----------

CREATE OR REPLACE TABLE silver.lead AS
SELECT
  Id                                        AS lead_id,
  TRIM(FirstName)                           AS first_name,
  TRIM(LastName)                            AS last_name,
  TRIM(Company)                             AS company,
  TRIM(Title)                               AS title,
  LOWER(TRIM(Email))                        AS email,
  COALESCE(TRIM(LeadSource), 'Unknown')     AS lead_source,
  TRIM(Status)                              AS lead_status,
  COALESCE(TRIM(Industry), 'Unknown')       AS industry,
  TRIM(City)                                AS city,
  TRIM(State)                               AS state,
  TRIM(Rating)                              AS rating,
  (COALESCE(IsConverted, FALSE) OR Status = 'Closed - Converted') AS is_converted,
  (Status LIKE 'Closed%')                   AS is_closed,
  CAST(CreatedDate AS TIMESTAMP)            AS created_at,
  CASE
    WHEN Company IS NULL OR TRIM(Company) = '' THEN FALSE
    WHEN Email IS NULL OR Email NOT RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN FALSE
    ELSE TRUE
  END AS is_valid,
  CONCAT_WS('; ',
    CASE WHEN Company IS NULL OR TRIM(Company) = '' THEN 'missing company' END,
    CASE WHEN Email IS NULL OR Email NOT RLIKE '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN 'missing or invalid email' END
  ) AS dq_reason
FROM bronze.lead;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Silver opportunity
-- MAGIC **Rules:** linked to an account, amount present and not negative, close date present.
-- MAGIC `stage_order` keeps chart stages in the right sequence.

-- COMMAND ----------

CREATE OR REPLACE TABLE silver.opportunity AS
SELECT
  Id                               AS opportunity_id,
  AccountId                        AS account_id,
  TRIM(Name)                       AS opportunity_name,
  StageName                        AS stage,
  CASE StageName
    WHEN 'Prospecting'          THEN 1
    WHEN 'Qualification'        THEN 2
    WHEN 'Needs Analysis'       THEN 3
    WHEN 'Value Proposition'    THEN 4
    WHEN 'Id. Decision Makers'  THEN 5
    WHEN 'Perception Analysis'  THEN 6
    WHEN 'Proposal/Price Quote' THEN 7
    WHEN 'Negotiation/Review'   THEN 8
    WHEN 'Closed Won'           THEN 9
    WHEN 'Closed Lost'          THEN 10
    ELSE 99
  END                              AS stage_order,
  CAST(Amount AS DECIMAL(18,2))    AS amount,
  CAST(Probability AS INT)         AS probability_pct,
  CAST(CloseDate AS DATE)          AS close_date,
  COALESCE(LeadSource, 'Unknown')  AS lead_source,
  COALESCE(Type, 'Unknown')        AS deal_type,
  CAST(IsWon AS BOOLEAN)           AS is_won,
  CAST(IsClosed AS BOOLEAN)        AS is_closed,
  CAST(CreatedDate AS TIMESTAMP)      AS created_at,
  CAST(LastModifiedDate AS TIMESTAMP) AS last_modified_at,
  CASE
    WHEN AccountId IS NULL                 THEN FALSE
    WHEN Amount IS NULL OR Amount < 0      THEN FALSE
    WHEN CloseDate IS NULL                 THEN FALSE
    ELSE TRUE
  END AS is_valid,
  CONCAT_WS('; ',
    CASE WHEN AccountId IS NULL THEN 'deal without account' END,
    CASE WHEN Amount IS NULL OR Amount < 0 THEN 'missing or negative amount' END,
    CASE WHEN CloseDate IS NULL THEN 'missing close date' END
  ) AS dq_reason
FROM bronze.opportunity;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Data quality summary
-- MAGIC One row per table. `pass_pct` is the percent of rows that passed all rules.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.data_quality_checks AS
WITH counts AS (
  SELECT 'Account' AS object_name, COUNT(*) AS total_rows,
         SUM(CASE WHEN is_valid THEN 0 ELSE 1 END) AS failed_rows
  FROM silver.account
  UNION ALL
  SELECT 'Contact', COUNT(*), SUM(CASE WHEN is_valid THEN 0 ELSE 1 END) FROM silver.contact
  UNION ALL
  SELECT 'Lead', COUNT(*), SUM(CASE WHEN is_valid THEN 0 ELSE 1 END) FROM silver.lead
  UNION ALL
  SELECT 'Opportunity', COUNT(*), SUM(CASE WHEN is_valid THEN 0 ELSE 1 END) FROM silver.opportunity
)
SELECT
  object_name,
  total_rows,
  failed_rows,
  ROUND(100.0 * (total_rows - failed_rows) / NULLIF(total_rows, 0), 1) AS pass_pct,
  current_timestamp() AS checked_at
FROM counts;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Overall data quality score
-- MAGIC One score for the dashboard (all tables together).

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.data_quality_score AS
SELECT
  SUM(total_rows)  AS total_rows,
  SUM(failed_rows) AS failed_rows,
  ROUND(100.0 * (SUM(total_rows) - SUM(failed_rows)) / NULLIF(SUM(total_rows), 0), 1) AS dq_score_pct,
  current_timestamp() AS checked_at
FROM gold.data_quality_checks;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Show the bad rows
-- MAGIC Returns nothing with the clean sample data. Add a bad record in Salesforce (for example a deal with a negative amount) and re-run to see it here.

-- COMMAND ----------

SELECT 'Account' AS object_name, account_id AS record_id, account_name AS record_name, dq_reason FROM silver.account WHERE NOT is_valid
UNION ALL
SELECT 'Contact', contact_id, full_name, dq_reason FROM silver.contact WHERE NOT is_valid
UNION ALL
SELECT 'Lead', lead_id, company, dq_reason FROM silver.lead WHERE NOT is_valid
UNION ALL
SELECT 'Opportunity', opportunity_id, opportunity_name, dq_reason FROM silver.opportunity WHERE NOT is_valid;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Quality per table
-- MAGIC **Expected:** `pass_pct` = 100 for our own records. Salesforce's built-in sample records may lower it slightly for some object; that is not an error.

-- COMMAND ----------

SELECT * FROM gold.data_quality_checks ORDER BY object_name;