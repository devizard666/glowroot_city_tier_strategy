"""
GlowRoot Synthetic Data Generator
==================================

Generates realistic, causally-structured synthetic data for the GlowRoot
city-tier expansion strategy project.

WHY THIS EXISTS (read this before touching the code):
GlowRoot is a fictional D2C skincare brand. Real companies don't publish
customer-level transaction data, so we simulate it. But a naive simulation
(independent random columns) produces data that doesn't behave like real
business data. This script fixes that by:

  1. Building variables in a causal chain (city tier -> delivery time ->
     return rate -> retention), not independently.
  2. Using skewed distributions (log-normal, beta, negative binomial)
     instead of normal distributions, matching how real business metrics
     actually distribute.
  3. Adding layered noise: a city-level random effect, a cohort/seasonality
     effect, and individual-level noise -- stacked, like real data.
  4. Deliberately NOT hard-coding the "answer." Cities are generated from
     demographic inputs; profitability is a downstream calculation, not
     an assumption.

Every parameter below is calibrated to a real range documented in
calibration_sources.md in this same folder -- see that file for citations.

Output: four CSVs written to ../01_data/generated/
  - cities.csv
  - customers.csv
  - orders.csv
  - marketing_spend.csv
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os

SEED = 42
rng = np.random.default_rng(SEED)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "01_data", "generated")
os.makedirs(OUTPUT_DIR, exist_ok=True)

START_DATE = datetime(2024, 1, 1)
END_DATE = datetime(2025, 12, 31)
TOTAL_DAYS = (END_DATE - START_DATE).days

N_CUSTOMERS = 42000

# ----------------------------------------------------------------------
# 1. CITIES TABLE
# ----------------------------------------------------------------------

CITY_DEFINITIONS = [
    ("Mumbai", "Maharashtra", 1), ("Delhi", "Delhi", 1), ("Bangalore", "Karnataka", 1),
    ("Hyderabad", "Telangana", 1), ("Chennai", "Tamil Nadu", 1), ("Pune", "Maharashtra", 1),
    ("Kolkata", "West Bengal", 1), ("Ahmedabad", "Gujarat", 1),
    ("Jaipur", "Rajasthan", 2), ("Lucknow", "Uttar Pradesh", 2), ("Indore", "Madhya Pradesh", 2),
    ("Coimbatore", "Tamil Nadu", 2), ("Surat", "Gujarat", 2), ("Nagpur", "Maharashtra", 2),
    ("Vadodara", "Gujarat", 2), ("Vijayawada", "Andhra Pradesh", 2), ("Bhopal", "Madhya Pradesh", 2),
    ("Patna", "Bihar", 2), ("Chandigarh", "Punjab", 2), ("Kochi", "Kerala", 2),
    ("Ludhiana", "Punjab", 2), ("Visakhapatnam", "Andhra Pradesh", 2),
    ("Ranchi", "Jharkhand", 3), ("Raipur", "Chhattisgarh", 3), ("Jodhpur", "Rajasthan", 3),
    ("Guwahati", "Assam", 3), ("Varanasi", "Uttar Pradesh", 3), ("Amritsar", "Punjab", 3),
    ("Madurai", "Tamil Nadu", 3), ("Siliguri", "West Bengal", 3), ("Dehradun", "Uttarakhand", 3),
    ("Jabalpur", "Madhya Pradesh", 3), ("Gwalior", "Madhya Pradesh", 3), ("Kota", "Rajasthan", 3),
]

STATE_INTERNET_NUDGE = {
    "Kerala": 0.06, "Maharashtra": 0.03, "Karnataka": 0.03, "Tamil Nadu": 0.02,
    "Gujarat": 0.02, "Punjab": 0.01, "Delhi": 0.03, "Telangana": 0.02,
    "West Bengal": -0.01, "Rajasthan": -0.02, "Madhya Pradesh": -0.03,
    "Uttar Pradesh": -0.06, "Bihar": -0.08, "Jharkhand": -0.05,
    "Chhattisgarh": -0.03, "Assam": -0.03, "Uttarakhand": 0.0, "Andhra Pradesh": 0.0,
}

TIER_BANDS = {
    1: dict(internet=(0.65, 0.75), income=(1.0, 1.0), pop_log_mean=15.8),
    2: dict(internet=(0.35, 0.55), income=(0.55, 0.75), pop_log_mean=14.6),
    3: dict(internet=(0.20, 0.35), income=(0.35, 0.55), pop_log_mean=13.8),
}

cities_rows = []
for city, state, tier in CITY_DEFINITIONS:
    band = TIER_BANDS[tier]
    nudge = STATE_INTERNET_NUDGE.get(state, 0.0)
    internet_penetration = np.clip(rng.uniform(*band["internet"]) + nudge, 0.10, 0.85)
    income_index = np.clip(rng.uniform(*band["income"]) + nudge * 0.5, 0.25, 1.15)
    population = int(np.exp(rng.normal(band["pop_log_mean"], 0.35)))
    city_random_effect = rng.normal(0, 0.08)
    cities_rows.append(dict(
        city=city, state=state, city_tier=tier,
        population=population,
        income_index=round(income_index, 3),
        internet_penetration=round(internet_penetration, 3),
        city_random_effect=round(city_random_effect, 4),
    ))

cities_df = pd.DataFrame(cities_rows)

# ----------------------------------------------------------------------
# 2. CUSTOMERS TABLE
# ----------------------------------------------------------------------

CHANNELS = ["Meta Ads", "Google Ads", "Influencer", "Organic/SEO", "Referral"]
CHANNEL_WEIGHTS = {
    1: [0.45, 0.25, 0.15, 0.10, 0.05],
    2: [0.35, 0.20, 0.20, 0.15, 0.10],
    3: [0.30, 0.15, 0.25, 0.15, 0.15],
}

city_weights = (cities_df["population"] * cities_df["internet_penetration"]) ** 0.5
city_weights = city_weights / city_weights.sum()

customer_city_idx = rng.choice(len(cities_df), size=N_CUSTOMERS, p=city_weights)
customers_cities = cities_df.iloc[customer_city_idx].reset_index(drop=True)

day_offsets = rng.triangular(0, TOTAL_DAYS, TOTAL_DAYS, size=N_CUSTOMERS).astype(int)
signup_dates = [START_DATE + timedelta(days=int(d)) for d in day_offsets]
festive_mask = rng.random(N_CUSTOMERS) < 0.08
festive_years = rng.choice([2024, 2025], size=N_CUSTOMERS)
for i in np.where(festive_mask)[0]:
    signup_dates[i] = datetime(int(festive_years[i]), 10, 15) + timedelta(days=int(rng.integers(0, 30)))

channels = []
for tier in customers_cities["city_tier"]:
    channels.append(rng.choice(CHANNELS, p=CHANNEL_WEIGHTS[tier]))

customers_df = pd.DataFrame({
    "customer_id": [f"CUST{100000+i}" for i in range(N_CUSTOMERS)],
    "city": customers_cities["city"],
    "city_tier": customers_cities["city_tier"],
    "signup_date": signup_dates,
    "acquisition_channel": channels,
})
customers_df["signup_date"] = pd.to_datetime(customers_df["signup_date"])
customers_df = customers_df.sort_values("signup_date").reset_index(drop=True)

# ----------------------------------------------------------------------
# 3. ORDERS TABLE
# ----------------------------------------------------------------------

merged = customers_df.merge(cities_df, on=["city", "city_tier"], how="left")

CATEGORIES = ["Face Care", "Body Care", "Hair Care", "Sunscreen", "Combo/Kit"]
CATEGORY_WEIGHTS = [0.35, 0.20, 0.15, 0.10, 0.20]
DELIVERY_BASE = {1: 2.2, 2: 4.0, 3: 6.0}
COD_SHARE = {1: 0.45, 2: 0.70, 3: 0.80}

orders_rows = []
order_counter = 0

for _, cust in merged.iterrows():
    tier = cust["city_tier"]
    income = cust["income_index"]
    city_effect = cust["city_random_effect"]

    months_active = max(1, (END_DATE - cust["signup_date"]).days / 30)
    base_rate = max(0.05, 0.35 + 0.15 * income + city_effect)
    n_orders = 1 + rng.negative_binomial(n=2, p=2 / (2 + base_rate * min(months_active, 18)))
    n_orders = min(n_orders, 14)

    cohort_month = cust["signup_date"].to_period("M")
    cohort_seed = hash(str(cohort_month)) % 1000
    cohort_effect = (cohort_seed / 1000 - 0.5) * 0.06

    for order_num in range(n_orders):
        order_counter += 1
        gap_days = int(rng.exponential(scale=45 + 20 * order_num))
        order_date = cust["signup_date"] + timedelta(days=gap_days * order_num + int(rng.integers(0, 5)))
        if order_date > END_DATE:
            break

        category = rng.choice(CATEGORIES, p=CATEGORY_WEIGHTS)
        category_base = {"Face Care": 650, "Body Care": 500, "Hair Care": 550,
                          "Sunscreen": 450, "Combo/Kit": 1200}[category]
        order_value = float(np.exp(rng.normal(np.log(category_base * (0.6 + 0.5 * income)), 0.35)))
        order_value = round(max(199, order_value), 2)

        delivery_days = max(1, rng.normal(DELIVERY_BASE[tier] - city_effect * 3, 1.2))
        delivery_days = round(delivery_days, 1)

        is_cod = rng.random() < (COD_SHARE[tier] + cohort_effect)

        base_return = {1: 0.14, 2: 0.24, 3: 0.32}[tier]
        delivery_penalty = max(0, (delivery_days - DELIVERY_BASE[tier]) * 0.015)
        cod_penalty = 0.06 if is_cod else -0.02
        repeat_discount = -0.02 * min(order_num, 3)
        return_prob = np.clip(
            base_return + delivery_penalty + cod_penalty + repeat_discount + city_effect,
            0.04, 0.65
        )
        is_returned = rng.random() < return_prob

        shipping_cost = round(max(25, 35 + delivery_days * 9 + rng.normal(0, 5)), 2)

        orders_rows.append(dict(
            order_id=f"ORD{200000+order_counter}",
            customer_id=cust["customer_id"],
            order_date=order_date,
            city=cust["city"],
            city_tier=tier,
            category=category,
            order_value=order_value,
            is_cod=is_cod,
            is_returned=is_returned,
            delivery_days=delivery_days,
            shipping_cost=shipping_cost,
        ))

orders_df = pd.DataFrame(orders_rows)
orders_df["order_date"] = pd.to_datetime(orders_df["order_date"])

# ----------------------------------------------------------------------
# 4. DELIBERATE MESSINESS
# ----------------------------------------------------------------------

def mess_up(df, cols_to_null, null_frac=0.02, dup_frac=0.005, seed=SEED):
    r = np.random.default_rng(seed)
    df = df.copy()
    n = len(df)
    for col in cols_to_null:
        idx = r.choice(n, size=int(n * null_frac), replace=False)
        df.loc[idx, col] = np.nan
    dup_idx = r.choice(n, size=int(n * dup_frac), replace=False)
    df = pd.concat([df, df.iloc[dup_idx]], ignore_index=True)
    return df

orders_df = mess_up(orders_df, cols_to_null=["delivery_days"], null_frac=0.015, dup_frac=0.004)

def scramble_city_name(name, r):
    variants = [name.upper(), name.lower(), f" {name} ", name.replace("a", "a ").strip()]
    return r.choice(variants)

scramble_idx = rng.choice(len(orders_df), size=int(len(orders_df) * 0.01), replace=False)
for i in scramble_idx:
    orders_df.loc[i, "city"] = scramble_city_name(orders_df.loc[i, "city"], rng)

# ----------------------------------------------------------------------
# 5. MARKETING SPEND TABLE
# ----------------------------------------------------------------------

RAW_CAC_TARGET = {1: (900, 1400), 2: (550, 850), 3: (500, 800)}

customers_df["signup_month"] = customers_df["signup_date"].dt.to_period("M")
new_cust_by_month_tier = customers_df.groupby(["signup_month", "city_tier"]).size().reset_index(name="new_customers")

spend_rows = []
for _, row in new_cust_by_month_tier.iterrows():
    tier = row["city_tier"]
    for channel in CHANNELS:
        w = CHANNEL_WEIGHTS[tier][CHANNELS.index(channel)]
        attributed_customers = max(1, int(row["new_customers"] * w))
        cac_target = rng.uniform(*RAW_CAC_TARGET[tier])
        spend = round(attributed_customers * cac_target * rng.uniform(0.9, 1.1), 2)
        impressions = int(spend / rng.uniform(0.15, 0.35))
        clicks = int(impressions * rng.uniform(0.008, 0.02))
        spend_rows.append(dict(
            month=str(row["signup_month"]), city_tier=tier, channel=channel,
            spend=spend, impressions=impressions, clicks=clicks,
            attributed_new_customers=attributed_customers,
        ))

marketing_spend_df = pd.DataFrame(spend_rows)

# ----------------------------------------------------------------------
# 6. WRITE OUTPUTS
# ----------------------------------------------------------------------

customers_df.drop(columns=["signup_month"]).to_csv(os.path.join(OUTPUT_DIR, "customers.csv"), index=False)
orders_df.to_csv(os.path.join(OUTPUT_DIR, "orders.csv"), index=False)
marketing_spend_df.to_csv(os.path.join(OUTPUT_DIR, "marketing_spend.csv"), index=False)
cities_df.to_csv(os.path.join(OUTPUT_DIR, "cities.csv"), index=False)

print(f"cities:           {len(cities_df):>7,} rows")
print(f"customers:        {len(customers_df):>7,} rows")
print(f"orders:           {len(orders_df):>7,} rows")
print(f"marketing_spend:  {len(marketing_spend_df):>7,} rows")
print(f"\nWritten to: {os.path.abspath(OUTPUT_DIR)}")

print("\n--- Sanity checks ---")
print("\nReturn rate by tier (should be roughly 12-18% / 20-30% / 28-40%):")
print(orders_df.groupby("city_tier")["is_returned"].mean().round(3))
print("\nAvg delivery days by tier:")
print(orders_df.groupby("city_tier")["delivery_days"].mean().round(2))
print("\nRaw CAC by tier (spend / attributed customers):")
raw_cac_check = marketing_spend_df.groupby("city_tier").apply(
    lambda d: d["spend"].sum() / d["attributed_new_customers"].sum()
)
print(raw_cac_check.round(2))
print("\nOrder value distribution (should be right-skewed):")
print(orders_df["order_value"].describe().round(2))
