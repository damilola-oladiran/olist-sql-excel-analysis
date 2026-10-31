use olist_clean;
show variables like 'local_infile';
show variables like 'secure_file_priv';


-- ORDERS_TABLE
load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/Data/olist_clean/olist_orders_dataset.csv"
into table orders
fields terminated by ',' optionally enclosed by '"'
lines terminated by '/n'
ignore 1 rows;
select count(*) from orders;


-- CUSTOMERS_TABLE
create table customers (customer_id varchar(50),customer_unique_id varchar(50),
                             customer_zip_code_prefix varchar(10),customer_city varchar(100),
                             customer_state varchar(5)
);

load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_customer_dataset.csv"
into table customers
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
select count(*) from customers;


-- ORDER_ITEMS TABLE
create table order_items (order_id varchar(50),order_item_id int,
                             product_id varchar(50),seller_id varchar(50),
                             shipping_limit_date datetime,price decimal(10,2),
                             freight_value decimal(10,2)
);

load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_order_items_dataset.csv"
into table order_items
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
select count(*) from order_items;


-- ORDER_PAYMENTS TABLE
create table order_payments (order_id varchar(50),payment_sequential int,
                             payment_type varchar(30),payment_installments int,
                             payment_value decimal(10,2)
);

load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_order_payments_dataset.csv"
into table order_payments
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
select count(*) from order_payments;


-- SELLERS TABLE
create table sellers (sellers_id varchar(50),seller_zip_code_prifix varchar(10),
                             seller_city varchar(100),seller_state varchar(5)
);
load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_sellers_dataset.csv"
into table sellers
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
select count(*) from sellers;


-- CATEGORY_TRANSLATION TABLE
create table category_translation (product_category_name varchar(100),
                                   product_category_name_english varchar(100)
                             
);
load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/product_category_name_translation.csv"
into table category_translation
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
select count(*) from category_translation;


-- PRODUCTS TABLE
create table products (product_id varchar(50),product_category_name varchar(100),
                             product_name_length int,product_description_length int,
                             product_photos_qty int,product_weight_g int,product_length_cm int,
                             product_height_cm int,product_width_cm int 
);
load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_products_dataset.csv"
into table products
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(product_id,product_category_name, @a, @b, @c, @d, @e, @f, @g)
set product_name_length = nullif(@a,''),
    product_description_length = nullif(@b,''),
    product_photos_qty = nullif(@c,''),
    product_weight_g= nullif(@d,''),
    product_length_cm = nullif(@e,''),
    product_height_cm = nullif(@f,''),
    product_width_cm = nullif(@g,'');
select count(*) from products;


-- REVIEWS TABLE
drop table if exists order_reviews;
create table order_reviews (review_id varchar(50),order_id varchar(50),
                             review_score int, review_comment_title text,
                             review_comment_message text,review_creation_date varchar(50),
                             review_answer_timestamp varchar(50)
);
load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/uploads/olist_order_reviews_dataset.csv"
ignore into table order_reviews
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;
select count(*) from order_reviews;

































































