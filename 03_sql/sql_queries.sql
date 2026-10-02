--total orders and revenue by city tier
select city_tier, count(*) as total_orders, 
round(sum(order_value)::numeric, 2) as total_revenue, 
round(avg(order_value)::numeric, 2) as avg_order_value
from orders
group by city_tier
order by city_tier;


--aov by city tier
select city_tier, 
round(avg(order_value)::numeric, 2) as aov,
round(min(order_value)::numeric, 2) as min_order,
round(max(order_value)::numeric, 2) as max_order
from orders
group by city_tier
order by city_tier;


--monthly new customer gain tier wise
select date_trunc('month', signup_date)::date as signup_month,
city_tier,
count(*) as new_customers
from customers
group by date_trunc('month', signup_date), city_tier
order by signup_month, city_tier;


--return rate by tier
select city_tier, count(*) as total_orders,
sum(case when is_returned then 1 else 0 end) as returned_orders,
round(100.0 * sum(case when is_returned then 1 else 0 end) / count(*), 2) as return_rate
from orders
group by city_tier
order by city_tier;


--CAC calculated on basis of marketing cost only

with new_cust_by_tier as(
	select city_tier, count(*) as new_cust
	from customers
	group by city_tier
),

spend_by_tier as (
	select city_tier, sum(spend) as total_spend
	from marketing_spend
	group by city_tier
)

select n.city_tier, n.new_cust, 
	round(s.total_spend::numeric, 2) as total_spend,
	round(s.total_spend/ n.new_cust::numeric, 2) as raw_cac
from new_cust_by_tier n
join spend_by_tier s on n.city_tier = s.city_tier
order by n.city_tier;



--tier 2 tier 3 have higher return rates than tier1 so
--we also need to consider return and shipping costs along with marketing to compute cac

with new_cust_by_tier as(
	select city_tier, count(*) as new_cust
	from customers
	group by city_tier
),

ad_spend as (
	select city_tier, sum(spend) as total_spend
	from marketing_spend
	group by city_tier
),

fulfillment_costs as (
	select
		city_tier, sum(shipping_cost) as total_sc,
		sum(case when is_returned then shipping_cost+150 else 0 end) as total_return_cost
	from orders
	group by city_tier
)

select
	c.city_tier, c.new_cust,
	round(a.total_spend::numeric, 2) as marketing_spend,
	round((a.total_spend/c.new_cust)::numeric, 2) as raw_cac,
	round(f.total_sc::numeric, 2) as total_sc,
	round(f.total_return_cost::numeric, 2) as total_return_cost,
	round(
        ((f.total_sc + f.total_return_cost) / c.new_cust)::numeric, 2
    ) as fulfillment_cost_per_customer,
    round(
        ((a.total_spend + f.total_sc + f.total_return_cost) / c.new_cust)::numeric, 2
    ) as fully_loaded_cac
from new_cust_by_tier c
join ad_spend a on c.city_tier = a.city_tier
join fulfillment_costs f on c.city_tier = f.city_tier
order by c.city_tier;


--90 day repeat purchase rate by tier

with orders_per_customer as (
    select
        c.customer_id,
        c.city_tier,
        c.signup_date,
        count(o.order_id) filter (
            where o.order_date <= c.signup_date + interval '90 days'
        ) as orders_in_first_90_days
    from customers c
    left join orders o
        on o.customer_id = c.customer_id
    group by c.customer_id, c.city_tier, c.signup_date
)
select
    city_tier,
    count(*) as total_customers,
    sum(case when orders_in_first_90_days >= 2 then 1 else 0 end) as repeat_customers,
    round(100.0 * sum(case when orders_in_first_90_days >= 2 then 1 else 0 end) / count(*), 2) as repeat_rate_90d_pct
from orders_per_customer
group by city_tier
order by city_tier;


--6month cohort retention table

with customer_orders as (
    select
        c.customer_id,
        c.city_tier,
        date_trunc('month', c.signup_date)::date as cohort_month,
        floor(
            (extract(year from age(o.order_date, c.signup_date)) * 12)
            + extract(month from age(o.order_date, c.signup_date))
        )::int as months_since_signup
    from customers c
    join orders o on o.customer_id = c.customer_id
    where o.order_date >= c.signup_date
),
cohort_sizes as (
    select city_tier, cohort_month, count(distinct customer_id) as cohort_size
    from customer_orders
    where months_since_signup = 0
    group by city_tier, cohort_month
),
active_by_month as (
    select city_tier, cohort_month, months_since_signup, count(distinct customer_id) as active_customers
    from customer_orders
    where months_since_signup between 0 and 6
    group by city_tier, cohort_month, months_since_signup
)
select
    a.city_tier,
    a.months_since_signup,
    round(avg(100.0 * a.active_customers / cs.cohort_size), 2) as avg_retention_pct,
    sum(a.active_customers) as total_active_customers,
    sum(cs.cohort_size) as total_cohort_size
from active_by_month a
join cohort_sizes cs on a.city_tier = cs.city_tier and a.cohort_month = cs.cohort_month
group by a.city_tier, a.months_since_signup
order by a.city_tier, a.months_since_signup;


--18 month ltv and ltv:cac ratio by tier

with customer_revenue as (
    select
        c.customer_id,
        c.city_tier,
        c.signup_date,
        sum(o.order_value) filter (
            where o.order_date <= c.signup_date + interval '18 months'
              and o.is_returned = false
        ) as revenue_18mo
    from customers c
    left join orders o on o.customer_id = c.customer_id
    where c.signup_date <= date '2025-12-31' - interval '18 months'
    group by c.customer_id, c.city_tier, c.signup_date
),
ltv_by_tier as (
    select city_tier, count(*) as eligible_customers,
        round(avg(coalesce(revenue_18mo, 0))::numeric, 2) as avg_ltv_18mo
    from customer_revenue
    group by city_tier
),
fully_loaded_cac as (
    select
        c.city_tier,
        round((
            (select sum(spend) from marketing_spend m where m.city_tier = c.city_tier)
            + (select sum(shipping_cost) from orders o where o.city_tier = c.city_tier)
            + (select sum(case when is_returned then shipping_cost + 150 else 0 end)
               from orders o where o.city_tier = c.city_tier)
        ) / count(distinct c.customer_id), 2) as fully_loaded_cac
    from customers c
    group by c.city_tier
)
select
    l.city_tier, l.eligible_customers, l.avg_ltv_18mo, f.fully_loaded_cac,
    round((l.avg_ltv_18mo / f.fully_loaded_cac)::numeric, 2) as ltv_to_cac_ratio_18mo
from ltv_by_tier l
join fully_loaded_cac f on l.city_tier = f.city_tier
order by l.city_tier;


--top 10/bottom 10 cities by ltv/cac

with eligible_customers as (
    select c.customer_id, c.city_tier, c.city, c.signup_date
    from customers c
    where c.signup_date <= date '2025-12-31' - interval '18 months'
),
customer_revenue as (
    select
        e.customer_id, e.city_tier, e.city,
        sum(o.order_value) filter (
            where o.order_date <= e.signup_date + interval '18 months'
              and o.is_returned = false
        ) as revenue_18mo
    from eligible_customers e
    left join orders o on o.customer_id = e.customer_id
    group by e.customer_id, e.city_tier, e.city
),
city_ltv as (
    select city_tier, city, count(*) as eligible_customers,
        round(avg(coalesce(revenue_18mo, 0))::numeric, 2) as avg_ltv_18mo
    from customer_revenue
    group by city_tier, city
),
city_costs as (
    select
        c.city, c.city_tier,
        count(distinct o.customer_id) as total_customers,
        sum(o.shipping_cost) as total_shipping_cost,
        sum(case when o.is_returned then o.shipping_cost + 150 else 0 end) as total_return_cost
    from cities c
    join orders o on trim(lower(o.city)) = trim(lower(c.city))
    group by c.city, c.city_tier
),
city_spend_allocated as (
    select
        cc.city, cc.city_tier, cc.total_customers, cc.total_shipping_cost, cc.total_return_cost,
        (select sum(spend) from marketing_spend m where m.city_tier = cc.city_tier)
            * (cc.total_customers::numeric / sum(cc.total_customers) over (partition by cc.city_tier))
            as allocated_spend
    from city_costs cc
)
select
    l.city, l.city_tier, l.eligible_customers, l.avg_ltv_18mo,
    round(((s.allocated_spend + s.total_shipping_cost + s.total_return_cost) / s.total_customers)::numeric, 2) as fully_loaded_cac,
    round((l.avg_ltv_18mo / ((s.allocated_spend + s.total_shipping_cost + s.total_return_cost) / s.total_customers))::numeric, 2) as ltv_to_cac_ratio_18mo
from city_ltv l
join city_spend_allocated s on l.city = s.city and l.city_tier = s.city_tier
where l.eligible_customers >= 30
order by ltv_to_cac_ratio_18mo desc --asc
limit 10;



--Delivery-day buckets vs return rate
--Business question: Does slower delivery really drive more
--returns, and how strong is that relationship?


select
    case
        when delivery_days <= 2 then '0-2 days'
        when delivery_days <= 4 then '3-4 days'
        when delivery_days <= 6 then '5-6 days'
        else '7+ days'
    end as delivery_bucket,
    city_tier,
    count(*) as total_orders,
    round(100.0 * sum(case when is_returned then 1 else 0 end) / count(*), 2) as return_rate_pct
from orders
where delivery_days is not null
group by delivery_bucket, city_tier
order by city_tier, delivery_bucket;



-- Running cumulative revenue by tier, month over month
-- Business question: What does each tier's growth trajectory
--   actually look like over the full 24-month window?

with monthly_revenue as (
    select
        city_tier,
        date_trunc('month', order_date)::date as order_month,
        sum(order_value) filter (where is_returned = false) as monthly_revenue
    from orders
    group by city_tier, date_trunc('month', order_date)
)
select
    city_tier,
    order_month,
    monthly_revenue,
    sum(monthly_revenue) over (
        partition by city_tier order by order_month
    ) as cumulative_revenue
from monthly_revenue
order by city_tier, order_month;


--percentile distribtuion of order value by tier

select
    city_tier,
    round(percentile_cont(0.25) within group (order by order_value)::numeric, 2) as p25,
    round(percentile_cont(0.50) within group (order by order_value)::numeric, 2) as median,
    round(percentile_cont(0.75) within group (order by order_value)::numeric, 2) as p75,
    round(percentile_cont(0.95) within group (order by order_value)::numeric, 2) as p95,
    round(avg(order_value)::numeric, 2) as mean
from orders
where is_returned = false
group by city_tier
order by city_tier;


-- ============================================================
-- Query 16: Product category mix by tier
-- Business question: Do customers in different tiers buy
--   different kinds of products? This checks whether AOV
--   differences (Query 2) are really a tier effect or just a
--   product-mix effect in disguise.
-- ============================================================

select
    city_tier,
    category,
    count(*) as orders,
    round(100.0 * count(*) / sum(count(*)) over (partition by city_tier), 2) as pct_of_tier_orders
from orders
group by city_tier, category
order by city_tier, pct_of_tier_orders desc;


-- ============================================================
-- Query 17: Month-over-month CAC trend by tier
-- Business question: Is CAC rising or falling over time in
--   each tier? A snapshot average can hide a worsening trend.
-- SQL concept: LAG() window function
-- ============================================================

with monthly_cac as (
    select
        month,
        city_tier,
        sum(spend) as monthly_spend,
        sum(attributed_new_customers) as monthly_new_customers,
        round(sum(spend) / nullif(sum(attributed_new_customers), 0), 2) as raw_cac
    from marketing_spend
    group by month, city_tier
)
select
    month,
    city_tier,
    raw_cac,
    lag(raw_cac) over (partition by city_tier order by month) as prev_month_cac,
    round(raw_cac - lag(raw_cac) over (partition by city_tier order by month), 2) as mom_change
from monthly_cac
order by city_tier, month;


-- ============================================================
-- Query 18: CAC by channel and tier
-- Business question: Not just WHERE to spend, but THROUGH
--   WHICH CHANNEL -- informs the how, not just the where.
-- ============================================================

select
    city_tier,
    channel,
    sum(spend) as total_spend,
    sum(attributed_new_customers) as new_customers,
    round(sum(spend) / nullif(sum(attributed_new_customers), 0), 2) as channel_cac
from marketing_spend
group by city_tier, channel
order by city_tier, channel_cac asc;


-- ============================================================
-- Query 19: Look-alike city screen
-- Business question: Which Tier-2/3 cities have demographics
--   (income, internet penetration) closest to Tier-1 profiles --
--   operationalizing the "look-alike" concept before Python
--   clustering formalizes it in Phase 6.
-- ============================================================

with tier1_benchmark as (
    select avg(income_index) as avg_income, avg(internet_penetration) as avg_internet
    from cities
    where city_tier = 1
)
select
    c.city,
    c.city_tier,
    c.income_index,
    c.internet_penetration,
    round(c.income_index - t.avg_income, 3) as income_gap_vs_tier1,
    round(c.internet_penetration - t.avg_internet, 3) as internet_gap_vs_tier1
from cities c
cross join tier1_benchmark t
where c.city_tier in (2, 3)
  and c.population > 1000000
  and c.internet_penetration >= (select percentile_cont(0.5) within group (order by internet_penetration) from cities where city_tier in (2,3))
order by (c.income_index + c.internet_penetration) desc;



-- ============================================================
-- Query 20: Contribution margin by tier
-- Business question: After EVERYTHING -- revenue, COGS proxy,
--   shipping, returns, and acquisition cost -- what's left?
-- Insight: The single most complete metric in the whole SQL
--   phase. Feeds directly into the financial model (Phase 8).
-- ============================================================

with revenue_and_costs as (
    select
        o.city_tier,
        sum(o.order_value) filter (where o.is_returned = false) as net_revenue,
        sum(o.order_value) filter (where o.is_returned = false) * 0.40 as cogs_proxy,  -- assume 40% COGS, typical for skincare
        sum(o.shipping_cost) as total_shipping_cost,
        sum(case when o.is_returned then o.shipping_cost + 150 else 0 end) as total_return_cost,
        count(distinct o.customer_id) as customers
    from orders o
    group by o.city_tier
),
spend as (
    select city_tier, sum(spend) as total_spend
    from marketing_spend
    group by city_tier
)
select
    r.city_tier,
    r.net_revenue,
    round(r.cogs_proxy::numeric, 2) as cogs_proxy,
    r.total_shipping_cost,
    r.total_return_cost,
    s.total_spend as marketing_spend,
    round((r.net_revenue - r.cogs_proxy - r.total_shipping_cost - r.total_return_cost - s.total_spend)::numeric, 2) as contribution_margin,
    round(((r.net_revenue - r.cogs_proxy - r.total_shipping_cost - r.total_return_cost - s.total_spend) / r.net_revenue * 100)::numeric, 2) as contribution_margin_pct
from revenue_and_costs r
join spend s on r.city_tier = s.city_tier
order by r.city_tier;


























