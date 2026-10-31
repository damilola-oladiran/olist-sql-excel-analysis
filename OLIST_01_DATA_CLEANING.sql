USE OLIST_CLEAN;
-- CHECKING ALL THE 8 TABLE
SELECT 'orders' as tbl, count(*) as n from orders 
union all select 'customers',count(*) from customers 
union all select 'order_items',count(*) from order_items 
union all select 'order_payments',count(*) from order_payments 
union all select 'order_reviews',count(*) from order_reviews 
union all select 'products',count(*) from products 
union all select 'sellers',count(*) from sellers 
union all select 'category_translation',count(*) from category_translation; 

-- CHECK: INVALID DATE FORMATS IN ORDERS.
select 
sum(order_purchase_timestamp <> '' and order_purchase_timestamp not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$') as bad_purchase,
sum(order_approved_at <> '' and order_approved_at not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')as bad_approved,
sum(order_delivered_carrier_date <> '' and order_delivered_carrier_date not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')as bad_carrier,
sum(order_delivered_customer_date <> '' and order_delivered_customer_date not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')as bad_customer,
sum(order_estimated_delivery_date <> '' and order_estimated_delivery_date not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')as bad_estimated
from orders;

-- BUILDING  NEW ORDERS_CLEAN TABLE.
set session sql_mode = '';
drop table if exists orders_clean;

create table orders_clean as 
select 
order_id,
customer_id,
order_status,
str_to_date(nullif(order_purchase_timestamp,''), '%Y-%m-%d %H:%i:%s') as order_purchase_timestamp,
str_to_date(nullif(order_approved_at,''), '%Y-%m-%d %H:%i:%s') as order_approved_at,
str_to_date(nullif(order_delivered_carrier_date,''), '%Y-%m-%d %H:%i:%s') as order_delivered_carrier_date,
str_to_date(nullif(order_delivered_customer_date,''), '%Y-%m-%d %H:%i:%s') as order_delivered_customer_date,
str_to_date(nullif(order_estimated_delivery_date,''), '%Y-%m-%d %H:%i:%s') as order_estimated_delivery_date
from orders;
describe orders_clean;
select count(*) from orders_clean;

-- CHECK: NO DATE LOST IN CONVERSION
select 
(select count(*) from orders where order_purchase_timestamp = '') as blank_purchase,
(select count(*) from orders_clean where order_purchase_timestamp is null) as null_purchase,
(select count(*) from orders where order_approved_at = '') as blank_approved,
(select count(*) from orders_clean where order_approved_at is null) as null_approved,
(select count(*) from orders where order_delivered_customer_date = '') as blank_delivered,
(select count(*) from orders_clean where order_delivered_customer_date is null) as null_delivered;

-- CHECK: INVALID DATE IN ORDER_REVIEWS (FOUND 1 BAD ROW)
select count(*) from order_reviews
where review_creation_date not regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}';
DROP table IF exists ORDER_REVIEWS_CLEAN;

-- BUILDING A NEW REVIEWS_CLEAN TABLE
create table order_reviews_clean as 
select 
review_id,
order_id,
review_score,
review_comment_title,
review_comment_message,
cast(review_creation_date as datetime) as review_creation_date,
cast(review_answer_timestamp as datetime) as review_answer_timestamp
from order_reviews
where review_creation_date regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
and review_answer_timestamp regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}';
select count(*) from order_reviews_clean;

