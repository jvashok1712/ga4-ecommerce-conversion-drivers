# 4. Predictive model with proper evaluation: train on November users, test on December users.
# Paste into a new Colab cell (or several). Uses your personal project only.

from google.colab import auth
auth.authenticate_user()

from google.cloud import bigquery
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score, average_precision_score, precision_score, recall_score

client = bigquery.Client(project="aha-moment-analysis")
df = client.query("""
SELECT
  first_week, device, medium,
  s1_page_views, s1_scrolls, s1_items_viewed, s1_items_clicked,
  s1_searches, s1_promo_views, s1_promo_clicks, s1_engaged_sec,
  CAST(converted_30d AS INT64) AS y
FROM `aha-moment-analysis.analysis.user_features_clean`
""").to_dataframe()

# --- features: only first-session behaviour (no cart / checkout, to avoid leakage) ---
num_cols = ["s1_page_views", "s1_scrolls", "s1_items_viewed", "s1_items_clicked",
            "s1_searches", "s1_promo_views", "s1_promo_clicks", "s1_engaged_sec"]
X = np.log1p(df[num_cols].fillna(0).astype(float))
X["viewed_product"] = (df["s1_items_viewed"] > 0).astype(int)
X = pd.concat([X, pd.get_dummies(df[["device", "medium"]].fillna("unknown"), drop_first=True, dtype=int)], axis=1)
y = df["y"]

# --- time-based split: learn from November, predict December ---
month = pd.to_datetime(df["first_week"]).dt.month
train, test = month == 11, month == 12
print(f"Train (Nov): {train.sum():,} users, {y[train].mean():.2%} buy")
print(f"Test  (Dec): {test.sum():,} users, {y[test].mean():.2%} buy")

scaler = StandardScaler().fit(X[train])
models = {
    "Logistic regression": LogisticRegression(max_iter=2000).fit(scaler.transform(X[train]), y[train]),
    "Gradient boosting": HistGradientBoostingClassifier(random_state=42).fit(X[train], y[train]),
}

def evaluate(name, scores):
    # Treat the top 10% highest-scored December users as "likely buyers"
    cutoff = np.quantile(scores, 0.90)
    pred = (scores >= cutoff).astype(int)
    return {
        "model": name,
        "AUC": round(roc_auc_score(y[test], scores), 3),
        "PR-AUC": round(average_precision_score(y[test], scores), 3),
        "precision@top10%": round(precision_score(y[test], pred), 3),
        "recall@top10%": round(recall_score(y[test], pred), 3),
    }

results = [
    evaluate("Logistic regression", models["Logistic regression"].predict_proba(scaler.transform(X[test]))[:, 1]),
    evaluate("Gradient boosting", models["Gradient boosting"].predict_proba(X[test])[:, 1]),
]

# Simple baseline: "viewed a product" rule (no model)
rule = X.loc[test, "viewed_product"]
results.append({
    "model": "Rule: viewed a product",
    "AUC": round(roc_auc_score(y[test], rule), 3),
    "PR-AUC": round(average_precision_score(y[test], rule), 3),
    "precision@top10%": round(precision_score(y[test], rule), 3),
    "recall@top10%": round(recall_score(y[test], rule), 3),
})

print(pd.DataFrame(results).to_string(index=False))
print(f"\nBase rate in December (random guessing precision): {y[test].mean():.3f}")
