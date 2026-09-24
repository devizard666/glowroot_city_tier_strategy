DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS marketing_spend;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS cities;



CREATE TABLE customers (
    customer_id           VARCHAR(15) PRIMARY KEY,
    city                  VARCHAR(50) REFERENCES cities(city),
    city_tier             SMALLINT,
    signup_date           DATE,
    acquisition_channel   VARCHAR(30)
);

-- orders.city is wider than cities.city as orders need cleaning before joining. 
-- order_id is NOT set as a strict
-- primary key because the raw data has ~0.4% intentional duplicate rows, simulating real world data.

CREATE TABLE orders (
    order_id              VARCHAR(15),
    customer_id           VARCHAR(15) REFERENCES customers(customer_id),
    order_date            DATE,
    city                  VARCHAR(60),
    city_tier             SMALLINT,
    category              VARCHAR(30),
    order_value           NUMERIC(10,2),
    is_cod                BOOLEAN,
    is_returned            BOOLEAN,
    delivery_days          NUMERIC(4,1),
    shipping_cost           NUMERIC(8,2)
);

CREATE TABLE marketing_spend (
    month                     VARCHAR(7),
    city_tier                 SMALLINT,
    channel                   VARCHAR(30),
    spend                     NUMERIC(12,2),
    impressions               INTEGER,
    clicks                    INTEGER,
    attributed_new_customers  INTEGER
);

CREATE TABLE cities (
    city                  VARCHAR(50) PRIMARY KEY,
    state                 VARCHAR(50),
    city_tier             SMALLINT,
    population            INTEGER,
    income_index          NUMERIC(5,3),
    internet_penetration  NUMERIC(5,3),
    city_random_effect    NUMERIC(6,4)
);

SELECT COUNT(*) FROM cities;
select count(*) from customers;
select count(*) from orders;
select count(*) from marketing_spend;