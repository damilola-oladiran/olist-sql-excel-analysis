# Olist E-Commerce Sales Analysis (SQL + Excel)

## Overview
An analysis of about 100,000 orders from a Brazilian e-commerce marketplace (Olist), using MySQL for cleaning and analysis and Excel for charts. The goal is to understand sales trends, product and regional performance, payment behaviour, and how delivery problems affect customer satisfaction.

## Business problem
Olist is a Brazilian online marketplace that connects small sellers with customers. This project asks: **where does the revenue come from, and what is holding back growth and customer satisfaction?** It looks at sales trends, product categories, regions, payment habits, delivery performance, sellers, and how many customers come back.

## Dataset
- **Source:** Brazilian E-Commerce Public Dataset by Olist (Kaggle): https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- **Period:** about 100,000 orders, 2016 to 2018
- **Files used (8 of 9):**

| Table | Rows |
|---|---|
| orders | 99,441 |
| customers | 99,441 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,223 (1 malformed row skipped on load) |
| products | 32,951 |
| sellers | 3,095 |
| category_translation | 71 |

- **Not used:** the geolocation file (about 1 million rows), because none of the questions need it.

## Tools used
- MySQL 8.0 (MySQL Workbench)
- Excel (charts)

## Data loading
1. The MySQL Table Data Import Wizard loaded only about 430 rows per minute, so it would have taken hours per table. I cancelled it.
2. Created each table myself with proper data types (dates as `datetime`, prices as `decimal`), because the wizard made every column `text`.
3. Loaded each CSV with `LOAD DATA INFILE` from MySQL's allowed uploads folder, which took seconds per file.
4. Checked every table's row count against the expected number from the dataset.

```sql
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
into table customers
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
```

## Data cleaning log
1. **Corrupted first import.** In my first import attempt, 197 rows in the orders table had product data (category names, sizes) in the date columns. I dropped everything and re-imported into a fresh database (`olist_clean`), loading one file at a time.
2. **Text dates.** The wizard stored all dates in the orders table as text. I built `orders_clean` with real `datetime` columns using `STR_TO_DATE`. A plain `CAST` failed with an "incorrect datetime value" error, and checks for bad formats and hidden characters found nothing, so I switched to `STR_TO_DATE` and verified nothing was lost: blank cells in the original equal NULLs in the new table (0 missing purchase dates, 160 missing approval dates, 2,965 missing delivery dates). `orders_clean` has all 99,441 rows.
3. **Blank cells.** Converted empty strings in the products and orders tables to real `NULL` values using `NULLIF`.
4. **Malformed review row.** One review comment contained a line break that broke row 77,917 of the reviews file. It was skipped on load. One more row with an invalid date was excluded when building `order_reviews_clean` (99,222 clean rows).
5. **Column spelling.** The original products file has misspelled headers (`product_name_lenght`, `product_description_lenght`). I created the table with the correct spelling (`..._length`) from the start, since the columns are loaded by position.

## Analysis
I answered nine business questions. Each one has the query, the result, a finding and, for the best ones, an Excel chart.

1. How many orders per month, and what is the trend?
2. What is the total revenue, and which months earn the most?
3. Which product categories bring in the most revenue?
4. Which states have the most customers and the highest sales?
5. Which payment methods do customers use most?
6. What is the average delivery time, and how many orders arrive late?
7. Do late deliveries get lower review scores?
8. Who are the top 10 sellers by revenue?
9. What share of customers order more than once?

### Question 1: How many orders were placed each month?

**Why it matters:** Monthly order volume shows whether the business is growing and when demand peaks, which helps with stock and marketing planning.

**Query:**
```sql
-- count orders per purchase month
select
  date_format(order_purchase_timestamp, '%Y-%m') as order_month,
  count(*) as total_orders
from orders_clean
group by order_month
order by order_month;
```

**Result:**

| order_month | total_orders |
|---|---|
| 2016-09 | 4 |
| 2016-10 | 324 |
| 2016-12 | 1 |
| 2017-01 | 800 |
| 2017-02 | 1,780 |
| 2017-03 | 2,682 |
| 2017-04 | 2,404 |
| 2017-05 | 3,700 |
| 2017-06 | 3,245 |
| 2017-07 | 4,026 |
| 2017-08 | 4,331 |
| 2017-09 | 4,285 |
| 2017-10 | 4,631 |
| 2017-11 | 7,544 |
| 2017-12 | 5,673 |
| 2018-01 | 7,269 |
| 2018-02 | 6,728 |
| 2018-03 | 7,211 |
| 2018-04 | 6,939 |
| 2018-05 | 6,873 |
| 2018-06 | 6,167 |
| 2018-07 | 6,292 |
| 2018-08 | 6,512 |
| 2018-09 | 16 |
| 2018-10 | 4 |

**Chart:**

![Monthly orders, Jan 2017 to Aug 2018](charts/q1_order_per_month_chart.png)

**Finding:** Monthly orders grew from 800 in January 2017 to a peak of 7,544 in November 2017, then levelled off at roughly 6,100 to 7,300 a month through August 2018. The November 2017 spike is likely a Black Friday effect (not confirmed). Data for September 2016 to December 2016 and for September and October 2018 is very thin (16 and 4 orders in the last two months), because the dataset starts and ends partway through those periods, so the trend should be read from January 2017 to August 2018.

**Yearly view (Q1b):**
```sql
-- orders per year (2016 and 2018 are partial years)
select date_format(order_purchase_timestamp, '%Y') as order_year,
       count(*) as total_orders
from orders_clean
group by order_year
order by order_year;
```

| order_year | total_orders |
|---|---|
| 2016 | 329 |
| 2017 | 45,101 |
| 2018 | 54,011 |

The yearly totals add up to all 99,441 orders. Because 2018 only covers January to August, the fair comparison is the same eight months: 22,968 orders in January to August 2017 against 53,991 in January to August 2018, about 135% higher.

---

### Question 2: How much revenue did we make each month, and what is the total?

**Why it matters:** Revenue shows which months bring in the most money, not just the most orders, and helps plan promotions and cash flow.

**Query:**
```sql
-- revenue per month = sum of item prices (cancelled and unavailable orders excluded)
select
  date_format(o.order_purchase_timestamp, '%Y-%m') as order_month,
  round(sum(oi.price), 2) as revenue
from orders_clean o
join order_items oi on o.order_id = oi.order_id
where o.order_status not in ('canceled', 'unavailable')
group by order_month
order by order_month;
```

**Result:**

| order_month | revenue |
|---|---|
| 2016-09 | 207.86 |
| 2016-10 | 44,507.30 |
| 2016-12 | 10.90 |
| 2017-01 | 120,098.27 |
| 2017-02 | 244,959.35 |
| 2017-03 | 368,341.32 |
| 2017-04 | 353,842.98 |
| 2017-05 | 503,159.19 |
| 2017-06 | 429,916.61 |
| 2017-07 | 492,287.30 |
| 2017-08 | 568,245.79 |
| 2017-09 | 621,415.91 |
| 2017-10 | 660,179.62 |
| 2017-11 | 1,003,862.14 |
| 2017-12 | 742,183.79 |
| 2018-01 | 945,456.29 |
| 2018-02 | 837,895.43 |
| 2018-03 | 981,051.06 |
| 2018-04 | 993,592.98 |
| 2018-05 | 992,871.75 |
| 2018-06 | 863,265.53 |
| 2018-07 | 878,044.27 |
| 2018-08 | 848,860.10 |
| 2018-09 | 145.00 |

No row exists for 2018-10: its 4 orders were most likely cancelled or unavailable, so the filter removed them. The monthly figures add up to the total revenue below, which I confirmed with a check query (`sum` of the monthly query's revenue column = 13,494,400.74).

*Note: my first monthly query had a typo (`'unavilable'`) in the status filter, so it did not exclude unavailable orders and October 2016 was overstated by about 2,008. Adding up the monthly numbers and comparing them with the total caught it.*

**Total revenue (Q2b):**
```sql
-- total revenue (excluding cancelled and unavailable orders)
select round(sum(oi.price), 2) as total_revenue
from orders_clean o
join order_items oi on o.order_id = oi.order_id
where o.order_status not in ('canceled', 'unavailable');
```
Total revenue: **13,494,400.74** (about 13.5 million).

**Chart:**

![Monthly revenue](charts/q2_monthly_revenue_chart.png)

**Finding:** Monthly revenue grew from about 120,000 in January 2017 to a peak of about 1.0 million in November 2017, the only month over 1 million and the same month as the order spike. Through early 2018 it stayed just under 1 million a month (945,000 to 994,000 from January to May), then fell about 13% from May to June 2018 (992,872 to 863,266), slightly more than the 10% fall in orders, and stayed between about 850,000 and 880,000 through August. September 2018 is a partial month. Across the whole period, total revenue came to about 13.5 million.

---

### Question 3: Which product categories bring in the most revenue?

**Why it matters:** Knowing which categories drive revenue shows where to focus marketing, stock and seller recruitment.

**Query:**
```sql
-- top 10 product categories by revenue, with English names
select
  coalesce(ct.product_category_name_english, nullif(p.product_category_name, ''), 'unknown') as category,
  round(sum(oi.price), 2) as revenue
from order_items oi
join orders_clean o on oi.order_id = o.order_id
join products p on oi.product_id = p.product_id
left join category_translation ct on p.product_category_name = ct.product_category_name
where o.order_status not in ('canceled', 'unavailable')
group by category
order by revenue desc
limit 10;
```

**Result:**

| category | revenue |
|---|---|
| health_beauty | 1,255,695.13 |
| watches_gifts | 1,198,185.21 |
| bed_bath_table | 1,035,964.06 |
| sports_leisure | 979,740.92 |
| computers_accessories | 904,322.02 |
| furniture_decor | 727,465.05 |
| housewares | 626,825.80 |
| cool_stuff | 620,770.49 |
| auto | 586,585.73 |
| garden_tools | 481,009.94 |

**Chart:**

![Top 10 product categories by revenue](charts/q3_top10_product_category_by_revenue_chart.png)

**Finding:** Three categories each earned over 1 million: health_beauty (1,255,695), watches_gifts (1,198,185) and bed_bath_table (1,035,964), together about 26% of total revenue. The top 10 categories add up to about 8.4 million, roughly 62% of the 13.5 million total, so revenue is concentrated in a small number of categories.

---

### Question 4: Which states have the most customers and the highest revenue?

**Why it matters:** Knowing where customers and revenue are concentrated helps decide where to focus marketing, delivery partnerships and seller recruitment.

**Query:**
```sql
-- top 10 states by revenue, with the number of unique customers
-- (customer_id is a new ID per order, so unique people are counted with customer_unique_id)
select
  c.customer_state as state,
  count(distinct c.customer_unique_id) as customers,
  round(sum(oi.price), 2) as revenue
from orders_clean o
join customers c on o.customer_id = c.customer_id
join order_items oi on o.order_id = oi.order_id
where o.order_status not in ('canceled', 'unavailable')
group by c.customer_state
order by revenue desc
limit 10;
```

**Result (state names added for readability; each row covers every city in that state):**

| state code | state name | customers | revenue |
|---|---|---|---|
| SP | São Paulo | 39,747 | 5,163,867.22 |
| RJ | Rio de Janeiro | 12,241 | 1,811,623.42 |
| MG | Minas Gerais | 11,134 | 1,573,508.20 |
| RS | Rio Grande do Sul | 5,233 | 742,559.78 |
| PR | Paraná | 4,824 | 676,883.06 |
| SC | Santa Catarina | 3,501 | 518,578.28 |
| BA | Bahia | 3,244 | 507,108.83 |
| DF | Distrito Federal | 2,057 | 300,886.45 |
| GO | Goiás | 1,934 | 287,870.46 |
| ES | Espírito Santo | 1,950 | 273,532.13 |

**Finding:** The state of São Paulo (all its cities combined) leads with 39,747 customers and 5,163,867 in revenue, about 38% of the 13.5 million total. São Paulo, Rio de Janeiro and Minas Gerais states together account for about 63% of revenue. Dividing revenue by customers gives about 130 per customer in São Paulo state, against roughly 140 to 156 in the other top-10 states, so São Paulo leads on volume rather than spend per customer.

---

### Question 5: Which payment methods do customers use most?

**Why it matters:** Payment preferences affect checkout design, partner fees and which instalment or voucher offers are worth running.

**Query:**
```sql
-- payment methods by number of orders and total paid
-- (an order can use more than one method, so the orders column adds up to more than the number of orders)
select
  payment_type,
  count(distinct order_id) as orders,
  round(sum(payment_value), 2) as total_paid
from order_payments
group by payment_type
order by orders desc;
```

**Result:**

| payment_type | orders | total_paid | share of orders | share of money |
|---|---|---|---|---|
| credit_card | 76,505 | 12,542,084.19 | 75.2% | 78.3% |
| boleto | 19,784 | 2,869,361.27 | 19.5% | 17.9% |
| voucher | 3,866 | 379,436.87 | 3.8% | 2.4% |
| debit_card | 1,528 | 217,989.79 | 1.5% | 1.4% |
| not_defined | 3 | 0.00 | 0.0% | 0.0% |

Shares are calculated against the sum of the orders column (101,686) and the sum of total_paid (about 16.0 million).

**Note:** total_paid is higher than the 13.5 million revenue in Q2 because payment_value includes shipping costs and covers cancelled orders too. The 3 `not_defined` rows have no value and can be ignored.

**Finding:** Credit card is by far the most used payment method, used in about 75% of payments and accounting for about 78% of the money paid. Boleto (a Brazilian bank slip) comes second at about 19.5% of payments. Vouchers and debit cards together make up about 5% of payments.

---

### Question 6: What is the average delivery time, and how many orders arrive late?

**Why it matters:** Delivery speed and reliability shape customer satisfaction, and knowing the late rate shows how much room there is to improve logistics.

**Query:**
```sql
-- delivery time and late deliveries (delivered orders only)
-- late = delivered on a later date than the estimated delivery date
select
  count(*) as delivered_orders,
  round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)), 1) as average_delivery_days,
  sum(date(order_delivered_customer_date) > date(order_estimated_delivery_date)) as late_orders,
  round(100 * sum(date(order_delivered_customer_date) > date(order_estimated_delivery_date)) / count(*), 1) as late_pct
from orders_clean
where order_status = 'delivered'
  and order_delivered_customer_date is not null;
```

**Result:**

| delivered_orders | average_delivery_days | late_orders | late_pct |
|---|---|---|---|
| 96,470 | 12.5 | 6,534 | 6.8 |

**Finding:** Delivered orders took 12.5 days on average to reach the customer, and 6,534 of 96,470 (6.8%) arrived after the estimated delivery date. Orders that were not delivered, such as cancelled or in-transit ones, are left out of this calculation. I compared dates and not full timestamps, because the estimated delivery date is stored at midnight and a delivery later on the estimated day should not count as late. About 93% of delivered orders arrived on or before the estimate.

**Q6b: promised vs actual delivery time**

```sql
select
  round(avg(datediff(order_estimated_delivery_date, order_purchase_timestamp)), 1) as avg_estimated_days,
  round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)), 1) as actual_days
from orders_clean
where order_status = 'delivered'
  and order_delivered_customer_date is not null
  and order_estimated_delivery_date is not null;
```

| avg_estimated_days | actual_days |
|---|---|
| 24.4 | 12.5 |

**Finding (Q6b):** Customers are promised delivery in about 24 days on average, but orders arrive in about 12.5. Olist's estimates are very conservative, roughly twice the real time, which keeps the late rate low but may make the marketplace look slower than it is at checkout.

---

### Question 7: Do late deliveries get lower review scores?

**Why it matters:** If late orders score much worse, fixing delivery reliability is a direct way to raise customer satisfaction.

**Query:**
```sql
-- average review score for late vs on-time deliveries
select
  case
    when date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
      then 'late'
    else 'on time or early'
  end as delivery_status,
  count(*) as reviews,
  round(avg(r.review_score), 2) as avg_review_score
from orders_clean o
join order_reviews_clean r on o.order_id = r.order_id
where o.order_status = 'delivered'
  and o.order_delivered_customer_date is not null
group by delivery_status;
```

**Result:**

| delivery_status | reviews | avg_review_score |
|---|---|---|
| on time or early | 89,942 | 4.29 |
| late | 6,409 | 2.27 |

**Finding:** Late deliveries score about 2 points lower (2.27 vs 4.29 out of 5). Although only about 7% of orders arrive late, they carry far worse reviews, so delivery reliability is the clearest lever for customer satisfaction. The review counts add up to 96,351 rather than 96,470 delivered orders because some delivered orders have no review.

**Chart:**

![Average review score, late vs on-time deliveries](charts/q7_avg_review_score_chart.png)

---

### Question 8: Who are the top 10 sellers by revenue?

**Why it matters:** Shows whether sales depend on a few big sellers and where they are based, which matters for seller support and risk.

**Query:**
```sql
-- top 10 sellers by revenue (cancelled and unavailable orders excluded)
select
  oi.seller_id,
  s.seller_state,
  count(distinct oi.order_id) as orders,
  round(sum(oi.price), 2) as revenue
from order_items oi
join orders_clean o on oi.order_id = o.order_id
join sellers s on oi.seller_id = s.sellers_id
where o.order_status not in ('canceled', 'unavailable')
group by oi.seller_id, s.seller_state
order by revenue desc
limit 10;
```

**Result:**

| Rank | seller_id (shortened) | State | Orders | Revenue |
|---|---|---|---|---|
| 1 | 4869f7a5... | SP | 1,131 | 229,237.63 |
| 2 | 53243585... | BA | 358 | 222,776.05 |
| 3 | 4a3ca931... | SP | 1,804 | 200,326.12 |
| 4 | fa1c13f2... | SP | 584 | 192,842.13 |
| 5 | 7c67e144... | SP | 982 | 187,923.89 |
| 6 | 7e93a43e... | SP | 332 | 172,583.88 |
| 7 | da8622b1... | SP | 1,314 | 160,236.57 |
| 8 | 7a67c85e... | SP | 1,159 | 141,715.54 |
| 9 | 1025f0e2... | SP | 915 | 138,968.55 |
| 10 | 955fee92... | SP | 1,286 | 135,159.70 |

**Finding:** The top 10 sellers earned about 1.78 million, around 13% of total revenue, from only 10 of 3,095 sellers (0.3%). Nine of the ten are in São Paulo state (SP). Only one, ranked second, is elsewhere (Bahia). The top seller leads by revenue, but the seller with the most orders (1,804) is only third, so some sellers sell cheaper items in higher volume. The sellers table spells its ID column `sellers_id`, so the join uses that name.

---

### Question 9: What share of customers order more than once?

**Why it matters:** Repeat buyers are cheaper to keep than new ones are to find, so the repeat rate shows how well the marketplace holds on to customers.

**Query:**
```sql
-- repeat customers (one person = customer_unique_id, because customer_id changes per order)
select
  count(*) as customers,
  sum(order_count > 1) as repeat_customers,
  round(100 * sum(order_count > 1) / count(*), 1) as repeat_pct
from (
  select c.customer_unique_id, count(distinct o.order_id) as order_count
  from orders_clean o
  join customers c on o.customer_id = c.customer_id
  where o.order_status not in ('canceled', 'unavailable')
  group by c.customer_unique_id
) t;
```

**Result:**

| customers | repeat_customers | repeat_pct |
|---|---|---|
| 94,990 | 2,888 | 3.0 |

**Finding:** Only 3.0% of customers (2,888 of 94,990) placed more than one order, so about 97% bought once and never came back. Counting by `customer_id` would have hidden this, because Olist creates a new `customer_id` for every order. Retention is the biggest growth opportunity in this data.

---

## Key findings
1. **Strong growth, then a plateau.** Orders rose from 800 in January 2017 to 7,544 in November 2017 (the peak), and held at roughly 6,100 to 7,300 a month through August 2018. Comparing January to August of each year, orders were about 135% higher in 2018 (53,991 vs 22,968).
2. **Revenue totals about 13.5 million**, with November 2017 the only month above 1 million. Revenue slipped about 13% from May to June 2018 and stayed lower.
3. **Revenue is concentrated.** Health & beauty, watches & gifts and bed, bath & table each earned over 1 million, and the top 10 categories make up about 62% of revenue. São Paulo state alone brings in about 38%, and the top three states about 63%.
4. **Credit card dominates payments** (about 75% of payments, 78% of the money paid). Boleto is second at about 19.5%.
5. **Deliveries are fast, but late ones hurt.** Orders arrive in 12.5 days on average and only 6.8% arrive after the estimated date. Those late orders score 2.27 out of 5 on reviews, against 4.29 for on-time or early ones.
6. **Estimates are very cautious.** Customers are promised delivery in about 24 days but get it in about 12.5.
7. **Sales depend on a small group of sellers.** The top 10 of 3,095 sellers earn about 13% of revenue, and nine of them are in São Paulo state.
8. **Few customers return.** Only 3.0% of customers (2,888 of 94,990) ordered more than once.

## Recommendations
1. **Focus on retention.** With about 97% of customers buying only once, small gains in repeat purchases would add more revenue than chasing new customers. Test follow-up offers or reminders after a first delivery, starting with the top categories.
2. **Cut late deliveries, especially with problem sellers and routes.** Late orders lose about 2 review points. Finding which sellers or states have the most late orders would be the next analysis.
3. **Use the delivery advantage in marketing.** Real delivery takes about half the promised time. More accurate estimates could make checkout more attractive, as long as late orders do not rise.
4. **Grow beyond São Paulo.** About 38% of revenue comes from one state. Seller recruitment and delivery partnerships in other regions would reduce that dependence.
5. **Plan promotions around the peak.** The November 2017 spike (likely Black Friday) shows what a campaign can do, and the plateau and mid-2018 dip suggest the need for new demand drivers.
6. **Support the top sellers.** A small group carries a large share of sales in the biggest categories, so protecting their service levels matters.

## Limitations
- Revenue counts item prices only (no freight) and excludes cancelled and unavailable orders.
- The data covers 2016 to 2018 and only part of 2016 and September to October 2018, so trends are read from January 2017 to August 2018.
- The November 2017 spike has not been tied to a specific event, so "Black Friday" is a likely explanation, not a proven one.
## What I learned
- Real data is messy. Checking row counts after every import caught a corrupted table early.
- The import wizard is convenient but slow, and `LOAD DATA INFILE` is far faster for large files.
- Choosing column data types up front saves cleaning work later.
- Always reconcile totals. Adding up my monthly revenue and comparing it with the overall total exposed a typo in a filter that MySQL accepted without any error.
- Joining on `customer_unique_id` instead of `customer_id` was needed to count real customers, because Olist creates a new `customer_id` for every order.
- Always reconcile totals. Adding up my monthly revenue and comparing it with the overall total exposed a typo in a filter that MySQL accepted without any error.
- Joining on `customer_unique_id` instead of `customer_id` was needed to count real customers, because Olist creates a new `customer_id` for every order.

## Contact
- Dami (Oladiran Monsura Damilola)
- LinkedIn: https://www.linkedin.com/in/oladiran-monsura-damilola-0a040826a
- Email: masuratuoladami@gmail.com

*Data credit: Olist, via Kaggle.*
