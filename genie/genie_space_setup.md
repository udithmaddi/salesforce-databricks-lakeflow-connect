# Genie space setup

Space name used in the workspace: `Sales and Lead Management` (you can rename it to `Sales Insights Genie`).

## Description

Ask questions about customers, pipeline, leads and sales from Salesforce data. Amounts are in INR.

## Compute

A serverless SQL warehouse.

## Sources (Unity Catalog tables, schema `crm_poc.gold`)

| Table | Description to paste (optional) |
| --- | --- |
| `customer_overview` | One row per valid account with contacts, deals, won revenue and open pipeline in INR |
| `opportunity_pipeline` | Open deals grouped by stage, industry, lead source and close month, with pipeline and weighted pipeline in INR |
| `lead_conversion` | Leads per lead source: total, converted, open and conversion percent |
| `sales_trends` | One row per month: won revenue, won and lost deals, average deal size and win rate |
| `lead_scores` | One row per open lead with a score from 0 to 100 and a grade of Hot, Warm or Cold |
| `at_risk_deals` | Open deals that are overdue, closing soon in an early stage, or big with low probability, with risk level and reason |
| `data_quality_checks` | Data quality per object (Account, Contact, Lead, Opportunity): total rows, failed rows and pass percent |

Do not add Bronze or Silver tables.

## General instructions

Paste the full content of `genie_general_instructions.txt` into **Instructions** > **General Instructions**.

## Sample questions (About tab, Common questions)

1. What is the total open pipeline by stage?
2. Which lead source has the highest conversion rate?
3. Show the top 5 customers by won revenue.
4. Which deals are overdue and what is their total value?
5. Which object has the most failed data quality rows?

## Example SQL (Examples tab, optional)

Open pipeline by stage in sales-process order:
```sql
SELECT stage, SUM(pipeline_inr) AS total_pipeline_inr
FROM crm_poc.gold.opportunity_pipeline
GROUP BY stage, stage_order
ORDER BY stage_order;
```

Top 5 customers by won revenue:
```sql
SELECT account_name, won_revenue_inr
FROM crm_poc.gold.customer_overview
ORDER BY won_revenue_inr DESC
LIMIT 5;
```

Lead sources ranked by conversion rate:
```sql
SELECT lead_source, conversion_pct
FROM crm_poc.gold.lead_conversion
ORDER BY conversion_pct DESC;
```

Data quality by object with an overall row:
```sql
SELECT object_name, total_rows, failed_rows, pass_pct
FROM (
  SELECT object_name, total_rows, failed_rows, CAST(pass_pct AS DOUBLE) AS pass_pct
  FROM crm_poc.gold.data_quality_checks
  UNION ALL
  SELECT 'Overall', SUM(total_rows), SUM(failed_rows),
         ROUND(100.0 * (SUM(total_rows) - SUM(failed_rows)) / SUM(total_rows), 1)
  FROM crm_poc.gold.data_quality_checks
)
ORDER BY CASE WHEN object_name = 'Overall' THEN 1 ELSE 0 END, object_name;
```

## Tests that passed

| Question | Expected behaviour |
| --- | --- |
| What is the total open pipeline by stage? | 8 stages in sales-process order; totals match the dashboard |
| Which lead source has the highest conversion rate? | All 5 sources ranked; Partner Referral first (about 42.6%) |
| Show the top 5 customers by won revenue. | Ranked list from `customer_overview`; matches the dashboard table |
| Which object has the most failed data quality rows? | Answer from `data_quality_checks` |
| Show data quality by object, with an overall row | 5 rows including Overall |
| Which objects have a pass percentage below 99? | Only objects strictly below 99 |
| What will our revenue be next quarter? | "I don't have that data in this space" (no forecasts) |
| Who is the CEO of Nova Pharma? | "I don't have that data in this space" |
| Why did the Account records fail? | "I don't have that data in this space" (reasons are only in Silver) |

Use **Show code** under each answer to check the SQL and the table used.

## Sharing

Click **Share** and add users. They need access to the Gold tables and permission to use the warehouse.
