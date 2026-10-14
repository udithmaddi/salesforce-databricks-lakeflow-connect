-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Step 6: Gold, business tables, lead scoring and at-risk deals
-- MAGIC **Reads:** `crm_poc.silver.*` (only rows where `is_valid = TRUE`)
-- MAGIC **Writes:** `crm_poc.gold.*`
-- MAGIC
-- MAGIC | Table | Answers |
-- MAGIC | --- | --- |
-- MAGIC | `customer_overview` | Who are our customers and how much do they bring? |
-- MAGIC | `opportunity_pipeline` | How many deals are open, in which stage? |
-- MAGIC | `lead_conversion` | Which lead sources turn into customers? |
-- MAGIC | `sales_trends` | How is revenue moving month by month? |
-- MAGIC | `lead_scores` | Which leads should sales call first (Hot / Warm / Cold)? |
-- MAGIC | `at_risk_deals` | Which open deals need attention now? |
-- MAGIC
-- MAGIC Amounts are in Indian Rupees (INR).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 0. Use the catalog

-- COMMAND ----------

USE CATALOG crm_poc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Customer overview
-- MAGIC One row per account: contacts, deals, open pipeline, won revenue.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.customer_overview AS
WITH contacts AS (
  SELECT account_id, COUNT(*) AS contact_count
  FROM silver.contact WHERE is_valid
  GROUP BY account_id
),
deals AS (
  SELECT
    account_id,
    COUNT(*)                                                    AS total_deals,
    SUM(CASE WHEN NOT is_closed THEN amount ELSE 0 END)         AS open_pipeline_inr,
    SUM(CASE WHEN is_won THEN amount ELSE 0 END)                AS won_revenue_inr,
    SUM(CASE WHEN is_won THEN 1 ELSE 0 END)                     AS won_deals
  FROM silver.opportunity WHERE is_valid
  GROUP BY account_id
)
SELECT
  a.account_id,
  a.account_name,
  a.industry,
  a.city,
  a.state,
  COALESCE(c.contact_count, 0)     AS contact_count,
  COALESCE(d.total_deals, 0)       AS total_deals,
  COALESCE(d.won_deals, 0)         AS won_deals,
  COALESCE(d.open_pipeline_inr, 0) AS open_pipeline_inr,
  COALESCE(d.won_revenue_inr, 0)   AS won_revenue_inr
FROM silver.account a
LEFT JOIN contacts c ON a.account_id = c.account_id
LEFT JOIN deals    d ON a.account_id = d.account_id
WHERE a.is_valid;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Opportunity pipeline
-- MAGIC Open deals by stage and expected close month. `weighted_pipeline_inr` = amount x probability.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.opportunity_pipeline AS
SELECT
  o.stage,
  o.stage_order,
  DATE_TRUNC('MONTH', o.close_date)  AS close_month,
  a.industry,
  o.lead_source,
  COUNT(*)                           AS deal_count,
  SUM(o.amount)                      AS pipeline_inr,
  SUM(o.amount * o.probability_pct / 100.0) AS weighted_pipeline_inr
FROM silver.opportunity o
JOIN silver.account a ON o.account_id = a.account_id
WHERE o.is_valid AND NOT o.is_closed
GROUP BY o.stage, o.stage_order, DATE_TRUNC('MONTH', o.close_date), a.industry, o.lead_source;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Lead conversion
-- MAGIC Total, converted and open leads by lead source, with conversion %.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.lead_conversion AS
SELECT
  lead_source,
  COUNT(*)                                          AS total_leads,
  SUM(CASE WHEN is_converted THEN 1 ELSE 0 END)     AS converted_leads,
  SUM(CASE WHEN NOT is_closed THEN 1 ELSE 0 END)    AS open_leads,
  ROUND(100.0 * SUM(CASE WHEN is_converted THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_pct
FROM silver.lead
WHERE is_valid
GROUP BY lead_source;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Sales trends
-- MAGIC Closed deals per month: won revenue, won and lost deals, average deal size, win rate.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.sales_trends AS
SELECT
  DATE_TRUNC('MONTH', close_date)                         AS month,
  SUM(CASE WHEN is_won THEN amount ELSE 0 END)            AS won_revenue_inr,
  SUM(CASE WHEN is_won THEN 1 ELSE 0 END)                 AS won_deals,
  SUM(CASE WHEN is_closed AND NOT is_won THEN 1 ELSE 0 END) AS lost_deals,
  ROUND(AVG(CASE WHEN is_won THEN amount END), 0)         AS avg_won_deal_inr,
  ROUND(100.0 * SUM(CASE WHEN is_won THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_closed THEN 1 ELSE 0 END), 0), 1) AS win_rate_pct
FROM silver.opportunity
WHERE is_valid AND is_closed
GROUP BY DATE_TRUNC('MONTH', close_date);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Lead scoring (Hot / Warm / Cold)
-- MAGIC A simple, explainable points system (0 to 100). Only open leads are scored.
-- MAGIC
-- MAGIC | Rule | Points |
-- MAGIC | --- | --- |
-- MAGIC | Rating | Hot +30, Warm +15 |
-- MAGIC | Lead source | Partner Referral +25, Web +15, Phone Inquiry +10 |
-- MAGIC | Status | Working - Contacted +20, Open - Not Contacted +5 |
-- MAGIC | Industry | Technology / Banking / Healthcare +10 |
-- MAGIC | Job title | CEO / CTO / Director / Head +15 |
-- MAGIC
-- MAGIC **Grade:** score 60 or more = Hot, 35 to 59 = Warm, below 35 = Cold.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.lead_scores AS
WITH scored AS (
  SELECT
    lead_id,
    CONCAT_WS(' ', first_name, last_name) AS lead_name,
    company, title, email, lead_source, lead_status, industry, city, rating,
    ( CASE rating WHEN 'Hot' THEN 30 WHEN 'Warm' THEN 15 ELSE 0 END
    + CASE lead_source WHEN 'Partner Referral' THEN 25 WHEN 'Web' THEN 15 WHEN 'Phone Inquiry' THEN 10 ELSE 0 END
    + CASE lead_status WHEN 'Working - Contacted' THEN 20 WHEN 'Open - Not Contacted' THEN 5 ELSE 0 END
    + CASE WHEN industry IN ('Technology', 'Banking', 'Healthcare') THEN 10 ELSE 0 END
    + CASE WHEN title RLIKE '(?i)CEO|CTO|Director|Head' THEN 15 ELSE 0 END
    ) AS lead_score
  FROM silver.lead
  WHERE is_valid AND NOT is_closed
)
SELECT
  *,
  CASE
    WHEN lead_score >= 60 THEN 'Hot'
    WHEN lead_score >= 35 THEN 'Warm'
    ELSE 'Cold'
  END AS lead_grade
FROM scored;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. At-risk deals
-- MAGIC Open deals that match any rule:
-- MAGIC - **Overdue:** close date passed but deal still open
-- MAGIC - **Closing soon, still early stage:** closes within 30 days, stage order 3 or lower
-- MAGIC - **Big deal, low probability:** amount 20 lakh or more and probability 20% or less
-- MAGIC
-- MAGIC Overdue deals are `High` risk, the rest `Medium`.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.at_risk_deals AS
WITH flagged AS (
  SELECT
    o.opportunity_id,
    o.opportunity_name,
    a.account_name,
    o.stage,
    o.amount            AS amount_inr,
    o.probability_pct,
    o.close_date,
    DATEDIFF(o.close_date, current_date()) AS days_to_close,
    CONCAT_WS('; ',
      CASE WHEN o.close_date < current_date() THEN 'Overdue' END,
      CASE WHEN o.close_date BETWEEN current_date() AND date_add(current_date(), 30)
                AND o.stage_order <= 3 THEN 'Closing soon, still early stage' END,
      CASE WHEN o.amount >= 2000000 AND o.probability_pct <= 20 THEN 'Big deal, low probability' END
    ) AS risk_reason
  FROM silver.opportunity o
  JOIN silver.account a ON o.account_id = a.account_id
  WHERE o.is_valid AND NOT o.is_closed
)
SELECT *,
  CASE WHEN risk_reason LIKE '%Overdue%' THEN 'High' ELSE 'Medium' END AS risk_level
FROM flagged
WHERE risk_reason <> '';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. (Optional) AI-written next action
-- MAGIC Uses the Databricks AI function `ai_gen`. If AI Functions are not enabled in your workspace, this cell fails: skip it, everything else still works.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.at_risk_deal_actions AS
SELECT
  opportunity_id,
  opportunity_name,
  account_name,
  risk_reason,
  ai_gen(CONCAT(
    'You are a sales coach. In one short sentence (max 25 words), suggest the next action ',
    'for this deal. Deal: ', opportunity_name, '. Stage: ', stage,
    '. Amount INR: ', CAST(amount_inr AS STRING), '. Close date: ', CAST(close_date AS STRING),
    '. Risk: ', risk_reason, '.'
  )) AS suggested_next_action
FROM gold.at_risk_deals;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Quick checks
-- MAGIC Lead grades

-- COMMAND ----------

SELECT lead_grade, COUNT(*) AS leads FROM gold.lead_scores GROUP BY lead_grade ORDER BY lead_grade;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Deals by risk

-- COMMAND ----------

SELECT risk_level, risk_reason, COUNT(*) AS deals
FROM gold.at_risk_deals GROUP BY risk_level, risk_reason ORDER BY deals DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Sales trends by month

-- COMMAND ----------

SELECT * FROM gold.sales_trends ORDER BY month;