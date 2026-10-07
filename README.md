# GA4 E-commerce Conversion Drivers: What Makes New Users Buy?

**An end-to-end product analytics project on Google's GA4 e-commerce data (BigQuery, SQL, Python, Data Studio).**

New users who view even one product in their first visit are far more likely to buy within 30 days, yet **4 in 5 new users never view a product**. This project finds that behaviour, checks it holds up under controls, sizes what it's worth, and designs the A/B test to prove it.

📊 **Dashboard:** [Aha Moment Analysis (Data Studio)](https://datastudio.google.com/reporting/c66b8feb-c480-46c6-889a-ad1f89b0b2f2)
📄 **One-page memo:** [docs/memo.md](docs/memo.md)

---

## Headline results

| Question | Answer |
| --- | --- |
| What predicts buying? | Viewing a product in the first session: **6.55%** 30-day conversion vs **0.31%** for non-viewers |
| Is it just engagement? | No. Controlling for engagement, device and channel, viewing a product still **doubles the odds** of buying (odds ratio **2.16**) |
| Does it hold everywhere? | Yes: viewers convert **17x–36x** more in every device, traffic source and country |
| Where do users leak? | **77.8%** of new users never view a product, the biggest drop in the funnel |
| When do buyers buy? | **67.6%** on the same day as their first visit; 85.2% within a week |
| Can we predict buyers on day one? | Yes: trained on November, tested on December, **AUC 0.94**; top 10% of scores captures **82%** of buyers |
| What is it worth? | +5 points of product-view rate ≈ **15–261 extra buyers** and **$1.3K–$22.3K** revenue per month |
| What should we do? | A/B test homepage product recommendations for new users; primary metric = first-session product-view rate (2-week test) |

## The business problem

Only 1.57% of new visitors to the Google Merchandise Store buy within 30 days. Acquisition is paid up front, so most new users are wasted spend. If we know which first-visit behaviour separates future buyers from everyone else (the "Aha moment"), the product team can design the first visit to push more people towards it.

## Data

- **Source:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce` (Google Merchandise Store, Nov 1 2020 – Jan 31 2021)
- **Cohort:** 168,498 users whose `first_visit` is between Nov 1 and Dec 31 2020, so everyone has a full 30-day window
- **After bot filter:** 167,441 users, 2,624 buyers
- **Outcome:** purchase within 30 days of first visit
- **Predictors:** behaviour in the first session only (page views, scrolls, products viewed/clicked, searches, promo views/clicks, engaged time)

## Method

1. **Cohort** – each user's `first_visit`, restricted so every user has 30 days of follow-up.
2. **First-session features** – unnest `event_params` for `ga_session_id`, count behaviour in that session.
3. **No circular predictors** – add-to-cart, checkout and purchase are excluded as predictors (they are part of buying).
4. **Validation** – one row per user; buyer counts match a direct count on raw events (2,624 vs 2,622 in the funnel query).
5. **Bot filter** – 1,057 users with 50+ page views and ≤1 scroll, zero purchases, removed.
6. **Lift analysis** – conversion for did vs didn't, and by number of products viewed.
7. **Segments** – device, traffic source, top countries.
8. **Funnel and time to purchase** – 30-day funnel and days-to-first-purchase distribution.
9. **Explanatory model** – logistic regression (statsmodels) with odds ratios.
10. **Predictive model** – logistic regression and gradient boosting, time-based split (train Nov, test Dec), AUC / PR-AUC / precision / recall.
11. **Impact sizing** – optimistic and conservative monthly value of a 5-point rise in product-view rate.
12. **Experiment design** – power analysis (statsmodels `NormalIndPower`) and a leading-indicator primary metric.
13. **Dashboard** – two-page Data Studio report on the `dash_*` tables: **Overview** (KPIs, conversion by products viewed, behaviour lift, weekly trend) and **Deep dives** (funnel, time to purchase, segment table).

## Key results

### Products viewed vs conversion

| Products viewed in first session | 30-day conversion |
| --- | --- |
| 0 | 0.31% |
| 1 | 1.81% (~6x) |
| 10+ | ~32% |

### Funnel (within 30 days)

| Step | Users | % of visitors | % of previous step |
| --- | --- | --- | --- |
| Visited site | 167,441 | 100% | |
| Viewed a product | 37,180 | 22.2% | 22.2% |
| Added to cart | 7,481 | 4.5% | 20.1% |
| Started checkout | 5,647 | 3.4% | 75.5% |
| Added payment info | 3,442 | 2.1% | 61.0% |
| Purchased | 2,622 | 1.6% | 76.2% |

### Explanatory model (logistic regression, odds ratios)

| Behaviour | Odds ratio |
| --- | --- |
| Viewed a product | **2.16** |
| Used site search | 0.66 |
| Clicked a promo | 0.60 |

Search and promo clicks look good in raw numbers but not once engagement is controlled, so investing in them would be misdirected.

### Predictive model (train Nov → test Dec)

| Model | AUC | PR-AUC | Precision (top 10%) | Recall (top 10%) |
| --- | --- | --- | --- | --- |
| Logistic regression | 0.937 | 0.369 | 11.2% | 82.3% |
| Gradient boosting | 0.943 | 0.349 | 11.2% | 82.4% |
| Rule: viewed a product | 0.843 | 0.058 | 6.6%* | 85.1%* |

\*The rule flags every viewer (~20% of users). Base rate in December: 1.36%. Logistic regression is chosen: same performance, fully explainable.

More result tables are in [`results/`](results/).

## Recommendation: A/B test

| Element | Design |
| --- | --- |
| Treatment | Homepage row of recommended products for new users |
| Split | New users only, 50/50 random |
| Primary metric | First-session product-view rate (baseline 20.2%) |
| Guardrails | 30-day conversion, revenue per user |
| Sample size | 6,426 per group (12,852 total) to detect a 10% relative lift ≈ 4.7 days of traffic → run **2 weeks** for full weekly cycles |
| Why not purchases? | At a 1.6% buy rate, detecting a 10% lift in conversion needs 206,392 users ≈ 75 days |

## Limitations

- Correlation, not proof of cause; the A/B test is what proves it.
- Google obfuscates this public dataset, which may flatten segment differences.
- Nov–Dec is holiday season; one store; revenue covers 30 days only.

## Repo structure

```
├── README.md
├── docs/
│   └── memo.md                  # 1-page memo for a VP
├── sql/
│   ├── 01_explore.sql             # raw data checks and conversion signal
│   ├── 02_cohort_features.sql     # new-user cohort + first-session features (user_features)
│   ├── 03_validation.sql          # row and buyer count checks
│   ├── 04_lift_and_bot_filter.sql # behaviour lift, thresholds, bot check, user_features_clean
│   ├── 05_dashboard_tables.sql    # dash_kpis, dash_products_viewed, dash_behaviour_lift, dash_weekly
│   ├── 06_segments.sql            # dash_segments
│   ├── 07_funnel.sql              # dash_funnel
│   ├── 08_impact_sizing.sql       # monthly value of +5 points product-view rate
│   └── 09_time_to_purchase.sql    # dash_time_to_purchase
├── notebooks/
│   ├── aha_moment_model.ipynb     # regression, power analysis, Nov->Dec predictive model (Colab)
│   └── predictive_model.py        # the predictive model as a standalone script
└── results/                     # result tables as CSV
```

## How to reproduce

1. Create a free Google Cloud project with the BigQuery sandbox and a dataset called `analysis` (location **US**, to match the public dataset). The queries use the project ID `aha-moment-analysis`; replace it with your own project ID.
2. Run the SQL files in order (01 → 09) in the BigQuery console. Expected counts are noted in comments.
3. Open the notebook in Google Colab, authenticate, and run all cells.
4. Connect Data Studio to the `dash_*` tables.

## Tools

BigQuery (SQL) · Python (pandas, statsmodels, scikit-learn) · Google Colab · Data Studio
