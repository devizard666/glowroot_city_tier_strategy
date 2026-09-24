# Calibration Sources — GlowRoot City-Tier Strategy Project

GlowRoot is a fictional company. The transaction-level data used in this project
(individual customers, orders, CAC, returns) is **synthetically generated** because
no real D2C brand publishes customer-level data publicly.

However, every distribution and parameter used to generate that synthetic data is
**calibrated to real, cited, publicly available benchmarks** from Indian D2C /
e-commerce industry reports. This file is the single source of truth for those
calibration numbers — every parameter in `generate_synthetic_data.py` should trace
back to a line in this file.

Where a source gives a range, we use the range as the plausible band for random
generation (not a single fixed number) — this is part of what keeps the simulated
data from looking artificially clean.

---

## 1. Internet Penetration & Digital Adoption by City Tier

| Metric | Value | Source |
|---|---|---|
| Total active internet users in India (2024) | 886 million (~58% of population) | IAMAI–Kantar, "Internet in India 2024" report |
| Urban internet users | 397 million | IAMAI–Kantar 2024 |
| Rural/non-metro internet users | 488 million (55% of total, now majority) | IAMAI–Kantar 2024 |
| Top-9 metro share of total internet users | 14% | IAMAI–Kantar 2024 (via Outlook Money coverage) |
| Small metros share | 9% | IAMAI–Kantar 2024 |
| Small towns (<10 lakh population) share | 22% | IAMAI–Kantar 2024 |
| Smartphone penetration in Tier-2 cities | Exceeds 70% | HavStrategy, "Marketing D2C Brand to Tier 2/3 India" (2026) |
| Household income growth in Tier-2 cities since 2018 | ~40% | HavStrategy (2026) |
| New online shoppers from Tier-2/3 cities | 60% of all new online shoppers | GrowEasy, "Lead Generation for D2C Brands" (2026); RedSeer via Inc42 cites up to 88% of shoppers 2020–2030 |

**Use in simulation:** `internet_penetration_index` by city tier — Tier-1/Metro ≈ 0.65–0.75, Tier-2 ≈ 0.35–0.55, Tier-3 ≈ 0.20–0.35. These bands directly reflect the urban/rural and metro/small-town splits above.

---

## 2. Customer Acquisition Cost (CAC) Benchmarks

| Metric | Value | Source |
|---|---|---|
| Blended D2C CAC, general (2023) | ₹800–1,200 | Troopod, "The CAC Crisis" blog (2025) |
| Blended D2C CAC, general (2024) | ₹1,200–1,800 | Troopod (2025) |
| Blended D2C CAC, general (2025) | ₹1,800–2,500 | Troopod (2025) |
| Fashion/beauty CAC, historical | ₹200–500 | Adtitude Media, "Why CAC Keeps Rising" (2026) |
| Fashion/beauty CAC, current | ₹800–1,200 | Adtitude Media (2026) |
| Meta ad CAC (2025 → 2026) | ₹380 → ₹502 (32% YoY rise) | Adtitude Media (2026) |
| General D2C CAC range (all channels) | ₹500–2,000 | ProductGrowth.in, "D2C Retention Playbook" (2026) |
| Best-performing brands' CAC | ₹600–900 | Troopod (2025) |
| Worst-performing brands' CAC | ₹2,000+ | Troopod (2025) |
| Efficient brands' CAC advantage in Tier-2/3 | "Lower CPMs plus adapted creative create lower CAC" | HavStrategy (2026) |

**Use in simulation:** `raw_cac_by_channel_tier` — Metro paid-channel CAC centered ~₹900–1,400 (skincare/beauty skews to the higher end of blended benchmarks); Tier-2/3 raw CAC centered ~₹550–900 (reflecting genuinely lower CPMs) — this lower *raw* number is what makes the naive "Tier-2 is cheaper" read plausible before fully-loaded costs are added.

---

## 3. Returns, RTO (Return-to-Origin), and Logistics

| Metric | Value | Source |
|---|---|---|
| RTO rate, festive quarter, COD orders | 58% | Unicommerce, "India D2C Report 2026" |
| RTO rate, festive quarter, prepaid orders | Under 15% | Unicommerce (2026) |
| National RTO rate (improved) | 39% (Nov 2025) → 21% (Feb 2026) | Whalesbook, citing Unicommerce data (2026) |
| COD share of non-metro e-commerce | 70% | Base.com, "Founder's Playbook" (2026) |
| COD share of all Indian e-commerce (historical) | 75% | Wikipedia, "E-commerce in India" |
| Tier 2/3 order share of incremental volume (FY26) | 66% | Unicommerce (2026) |

**Use in simulation:** `return_rate` — Metro ≈ 12–18% (more prepaid, denser logistics); Tier-2 ≈ 20–30%; Tier-3 ≈ 28–40% (higher COD share, longer delivery, matches the RTO figures above). `cod_share_by_tier` — Metro ≈ 40–50%, Tier-2 ≈ 65–75%, Tier-3 ≈ 75–85%.

---

## 4. Contribution Margin, Payback Period & Profitability

| Metric | Value | Source |
|---|---|---|
| D2C brands still contribution-margin negative at order level (2020–22 cohort, as of mid-2024) | 68% | CRISIL 2024 D2C Credit Assessment Report (via FirstUnicornStartup) |
| Average payback period, fashion/beauty D2C | 18–24 months | RedSeer analysis, late 2023 (via FirstUnicornStartup) |
| 180-day repeat purchase rate | Rarely exceeds 30% | RedSeer / FirstUnicornStartup summary (2026) |
| Profitable D2C companies (FY23) | Only 24 of 170+ established companies | Whalesbook (2026), citing industry tracking |
| Healthy LTV:CAC ratio benchmark | 3:1 or better | Razorpay Learn, "CAC: A D2C Guide" (2026); GrowthByte D2C CAC Benchmarks (2026) |
| Typical % of revenue spent on paid acquisition | 50–70% | BrandLoom, "2026 Growth Efficiency Report" |

**Use in simulation:** `retention_decay_curve` calibrated so 180-day repeat purchase rate lands 20–30% in the base case (weighted toward the lower/typical end per RedSeer), with Tier-1 modestly higher than Tier-2/3 reflecting logistics/trust factors. `payback_period_months` target range 12–24 months across the simulated cohort, consistent with the RedSeer 18–24 month figure representing a "concerning but common" case rather than a worst case.

---

## 5. Category & AOV Notes

| Metric | Value | Source |
|---|---|---|
| Category retention differences | Consumable/replenishment categories (Beauty, FMCG) structurally advantaged over durable/low-frequency (Fashion, Home) | SourceryIntel, "India's D2C Ecosystem" report |
| Shipping cost risk zone | ₹500–1,500 price range — "shipping cost differences can wipe out margins" | SourceryIntel |
| AOV/pricing trend (FY26) | GMV and order volume both grew ~33-34%; prices roughly flat — growth driven by volume, not price increases | Unicommerce, "India D2C Report 2026" |

**Use in simulation:** GlowRoot is a skincare/personal-care brand — a replenishment category — which justifies using the *more favorable* end of retention benchmarks relative to fashion, while still respecting the overall 20-30% repeat-rate ceiling from RedSeer.

---

## 6. Known Limitations of This Calibration

- These are **industry-wide blended benchmarks**, not GlowRoot-specific — real company data would show more idiosyncratic variation (single-city effects, specific campaign anomalies) that no calibration to aggregate reports can fully capture.
- Several sources are marketing/agency blogs rather than primary research (Troopod, Adtitude, HavStrategy) — used because they cite plausible, internally consistent ranges, but they are lower-confidence than RedSeer/CRISIL/IAMAI-Kantar, which are flagged above as primary or near-primary sources.
- CAC figures are inflating rapidly year over year in this market (documented 30-50% YoY increases across sources) — this project uses FY25/FY26-era figures; if revisited later, ranges should be re-pulled rather than assumed static.
- Return-rate and RTO figures vary heavily by season (festive quarter cited separately) — the simulation uses steady-state annual averages, not seasonal peaks, and this simplification should be stated explicitly in the final memo.
