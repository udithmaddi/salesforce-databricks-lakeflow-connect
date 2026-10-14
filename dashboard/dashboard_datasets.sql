-- Step 7: dashboard datasets. In the dashboard Data tab click Create from SQL once per query and use the dataset name shown.


-- Dataset 1: ds_kpis
SELECT
  (SELECT COUNT(*) FROM crm_poc.gold.customer_overview)                    AS total_customers,
  (SELECT SUM(pipeline_inr) FROM crm_poc.gold.opportunity_pipeline)        AS open_pipeline_inr,
  (SELECT SUM(won_revenue_inr) FROM crm_poc.gold.sales_trends)             AS won_revenue_inr,
  (SELECT ROUND(100.0 * SUM(converted_leads) / SUM(total_leads), 1)
     FROM crm_poc.gold.lead_conversion)                                    AS lead_conversion_pct,
  (SELECT dq_score_pct FROM crm_poc.gold.data_quality_score)               AS dq_score_pct;


-- Dataset 2: ds_pipeline_by_stage
SELECT stage, stage_order, industry, lead_source, close_month,
       SUM(deal_count)            AS deals,
       SUM(pipeline_inr)          AS pipeline_inr,
       SUM(weighted_pipeline_inr) AS weighted_pipeline_inr
FROM crm_poc.gold.opportunity_pipeline
GROUP BY stage, stage_order, industry, lead_source, close_month
ORDER BY stage_order;


-- Dataset 3: ds_sales_trends
SELECT month, won_revenue_inr, won_deals, lost_deals, avg_won_deal_inr, win_rate_pct
FROM crm_poc.gold.sales_trends
ORDER BY month;


-- Dataset 4: ds_lead_conversion
SELECT lead_source, total_leads, converted_leads, open_leads, conversion_pct
FROM crm_poc.gold.lead_conversion
ORDER BY conversion_pct DESC;


-- Dataset 5: ds_top_customers
SELECT account_name, industry, city, contact_count, won_deals,
       won_revenue_inr, open_pipeline_inr
FROM crm_poc.gold.customer_overview
ORDER BY won_revenue_inr DESC
LIMIT 10;


-- Dataset 6: ds_hot_leads
SELECT lead_grade, lead_score, lead_name, company, title, lead_source, rating, city, email
FROM crm_poc.gold.lead_scores
ORDER BY lead_score DESC;


-- Dataset 7: ds_at_risk_deals
SELECT risk_level, opportunity_name, account_name, stage, amount_inr,
       close_date, days_to_close, risk_reason
FROM crm_poc.gold.at_risk_deals
ORDER BY risk_level, amount_inr DESC;


-- Dataset 8: ds_data_quality
SELECT object_name, total_rows, failed_rows, pass_pct, checked_at
FROM crm_poc.gold.data_quality_checks
ORDER BY object_name;
