# GlowRoot: Should a D2C Brand Expand to Tier-2/3 Cities?

**A business-analytics portfolio project** — simulating a real strategic decision facing Indian D2C brands: whether to shift marketing budget from saturated metro markets into under-penetrated Tier-2/3 cities.

> GlowRoot is a fictional skincare brand. The transaction data is synthetically generated, but every parameter is calibrated to real, cited industry benchmarks (IAMAI-Kantar, RedSeer, CRISIL, Unicommerce) — see [`02_data_generation/calibration_sources.md`](02_data_generation/calibration_sources.md) for full sourcing.

---

## The Headline Finding

The obvious, naive answer — "Tier-2/3 customers are cheaper to acquire, so shift budget there" — is wrong, and wrong in a more interesting way than expected:

1. **Raw CAC is genuinely lower in Tier-2/3** (~45% cheaper in Tier-3 vs. Tier-1) — this is the number a rushed analysis would stop at.
2. **Once shipping and return costs are added**, that advantage shrinks by roughly half (to ~24%) — slower delivery to smaller cities drives meaningfully higher return rates.
3. **Once full unit economics are applied** (COGS, shipping, returns, and acquisition cost together), **every tier is contribution-margin negative** — and Tier-3 is the worst of the three, losing nearly 45 paise per rupee of revenue vs. Tier-1's ~16 paise.

**The real recommendation this data supports is not "shift budget to Tier-2/3" — it's "pause tier-wide expansion and fix unit economics in Tier-1 first,"** where the business is closest to breakeven. This is the opposite of the intuitive answer, and it mirrors a well-documented pattern in real Indian D2C (CRISIL's 2024 report found 68% of D2C brands are still contribution-margin negative at the order level).

---

## Project Status

| Phase | Status |
|---|---|
| Business problem framing & hypotheses | ✅ Done |
| Calibrated synthetic data generation | ✅ Done |
| SQL analysis (20 queries) | ✅ Done |
| Python analytics (clustering, regression, scenarios) | 🔜 In progress |
| Financial model (Excel) | ⬜ Not started |
| Power BI dashboard | ⬜ Not started |
| Strategy deck & recommendation memo | ⬜ Not started |

---

## Repo Structure

```
01_data/              Calibrated synthetic dataset (cities, customers, orders, marketing spend)
02_data_generation/   Calibration sources + the data generation script
03_sql/               Schema + 20 progressive SQL analyses, with key outputs exported
04_python_analysis/   EDA, city clustering, regression, scenario modeling
05_financial_model/   Unit-economics Excel model
06_dashboard/         Power BI dashboard + screenshots
07_deliverables/      Strategy deck + recommendation memo
images/               Key charts referenced in this README
```

---

## Methodology Note: Why Synthetic Data

No D2C brand publishes customer-level transaction data publicly. Rather than limit this project to thin, aggregate public filings, I built a synthetic dataset with a deliberate **causal structure** (city tier → delivery time → return likelihood, income → order value, etc.) instead of independently random columns, and calibrated every distribution to real published ranges. The data also includes intentional imperfections — missing values, duplicate rows, inconsistent city-name formatting — to make the data-cleaning step genuine rather than cosmetic. Full sourcing and known limitations are documented in [`calibration_sources.md`](02_data_generation/calibration_sources.md).

---

## Key SQL Findings So Far

| Metric | Tier 1 (Metro) | Tier 2 | Tier 3 |
|---|---|---|---|
| Raw CAC | ₹1,154 | ₹712 | ₹629 |
| Fully-loaded CAC (+ shipping/returns) | ₹1,376 | ₹1,056 | ₹1,041 |
| Return rate | 14.5% | 28.4% | 33.1% |
| 18-month LTV : CAC | 2.23 | 1.99 | 1.67 |
| Contribution margin | -15.97% | -23.57% | -44.72% |

See [`03_sql/analysis_queries.sql`](03_sql/analysis_queries.sql) for all 20 queries, each documented with its business question, SQL concept used, and why the result matters.

---

## Tech Stack

- **PostgreSQL** — schema design, 20 progressive analytical queries
- **Python** (pandas, numpy) — synthetic data generation; clustering/regression to follow
- **Excel** — unit-economics financial model (to follow)
- **Power BI** — executive dashboard (to follow)

---

## What's Next

Phase 6 (Python) will formalize the city-level "look-alike" screening that Query 11/19 approximated in SQL, using k-means clustering on income and internet-penetration data — testing whether any individual Tier-2/3 cities buck the tier-wide negative-margin pattern found above.