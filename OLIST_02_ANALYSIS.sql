USE OLIST_CLEAN;
-- Q1: HOW MANY ORDERS WHERE PLACED EACH MONTH (recorded)
select date_format(order_purchase_timestamp, '%Y-%m')as order_month,
count(*) as total_orders
from orders_clean
group by order_month
order by order_month;

-- Q1B: ORDERS PER YEAR
select date_format(order_purchase_timestamp, '%Y') as order_year,
count(*) as total_order
from orders_clean
group by order_year
order by order_year asc;

-- Q2: HOW MANY REVENUE DID WE MAKE EACH MONTH (recorded)
select 
date_format(o.order_purchase_timestamp, '%Y-%m') as order_month,
round(sum(oi.price), 2) as revenue 
from orders_clean o 
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable')
group by order_month
order by order_month;

-- Q2B: TOTAL REVENUE (EXCLUDING CANCELLED AND UNAVAILABLE ORDERS)
select round(sum(oi.price), 2) as total_revenue 
from orders_clean o
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable');

-- CHECK: DO THE MONTHLY FIGURES ADD UP TO THE TOTALS ?
select round(sum(revenue), 2) as monthly_sum
from(
select date_format(o.order_purchase_timestamp, '%Y-%m') as order_month,
       sum(oi.price) as revenue
from orders_clean o 
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable')
group by order_month
) t;       

-- Q3: TOP 10 PRODUCT CATEGORIES BY REVENUE (ENGLISH NAMES)
select 
coalesce(ct.product_category_name_english, nullif(p.product_category_name, ''), 'unknown') as category,
round(sum(oi.price), 2) as revenue
from order_items oi
join orders_clean o on oi.order_id = o.order_id
join products p on oi.product_id =p.product_id 
left join category_translation ct on p.product_category_name =ct.product_category_name 
where o.order_status not in ('canceled','unavailable')
group by category
order by revenue desc
limit 10;

-- Q4: TOP 10 STATE BY REVENUE, WITH NUMBER OF UNIQUE CUSTOMERS
select 
c.customer_state as state,
count(distinct c.customer_unique_id) as customers,
round(sum(oi.price), 2) as revenue 
from orders_clean o
join customers c on o.customer_id =c.customer_id
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable')
group by c.customer_state 
order by revenue desc 
limit 10;

-- Q4B: TOP 10 CITIES BY REVENUE
select
c.customer_city as city,
c.customer_state as state,
count(distinct c.customer_unique_id) as customers,
round(sum(oi.price), 2) as revenue 
from orders_clean o
join customers c on o.customer_id =c.customer_id
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable')
group by c.customer_city, c.customer_state
order by revenue desc
limit 10;

-- Q5: PAYMENT METHODS BY NUMBER OF ORDERS AND TOTAL PAID 
select
payment_type,
count(distinct order_id) as orders,
round(sum(payment_value), 2) as total_paid 
from order_payments
group by payment_type
order by orders desc;

-- Q6:AVERAGE DELIVERY TIME AND LATE DELIVERIES (DELIVERED ORDERS ONLY)
select 
count(*)as delivered_orders,
round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)), 1) as average_delivery_days,
sum(date(order_delivered_customer_date)> date(order_estimated_delivery_date)) as late_orders,
round(100 * sum(date(order_delivered_customer_date)>date(order_estimated_delivery_date))/ count(*), 1) as late_pct
from orders_clean
where order_status = 'delivered'
and order_delivered_customer_date is not null;

-- Q6B: PROMISE VS ACTUAL DELEVERY TIME
select
round(avg(datediff(order_estimated_delivery_date, order_purchase_timestamp)), 1) as avg_estimated_days,
round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)), 1) as actual_days
from orders_clean 
where order_status = 'delivered'
  and order_estimated_delivery_date is not null;

-- Q7: AVERAGE REVIEWS SCORE FOR LATE VS ON_TIME DELIVERIES
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
where o.order_status ='delivered'
   and o.order_delivered_customer_date is not null
   group by delivery_status;

-- Q8: TOP 10 SELLERS BY REVENUE
select 
oi.seller_id,
s.seller_state,
count(distinct oi.order_id) as orders,
round(sum(oi.price), 2) as revenue 
from order_items oi 
join orders_clean o on oi.order_id = o.order_id
join sellers s on oi.seller_id =s.sellers_id
where o.order_status not in ('canceled','unavailable')
group by oi.seller_id,s.seller_state
order by revenue desc
limit 10;

-- Q9: REPEAT CUSTOMERS 
select
count(*) as customers,
sum(order_count >1) as repeat__customers,
round(100 * sum(order_count > 1) / count(*),1) as repeat_pct
from(
select c.customer_unique_id, count(distinct o.order_id) as order_count
from orders_clean o 
join customers c on o.customer_id = c.customer_id
where o.order_status not in ('canceled','unavailable')
group by c.customer_unique_id
)t;


-- CHECK: MONTHLY REVENUE ADDS UP TO TOTAL REVENUE 

use olist_clean;
select round(sum(oi.price), 2) as total_revenue
from orders_clean o
join order_items oi on o.order_id =oi.order_id
where o.order_status not in ('canceled','unavailable');

select round(sum(revenue), 2) as monthly_sum
from(
select 
date_format(o.order_purchase_timestamp, '%Y'-'%m') as order_month,
round(sum(oi.price), 2) as revenue
from orders_clean o 
join order_items oi on o.order_id = oi.order_id
where o.order_status not in ('canceled','unavailable')
group by order_month
)t;









