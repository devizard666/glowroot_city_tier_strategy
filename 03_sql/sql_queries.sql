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

--repeat purchase rate by tier

















