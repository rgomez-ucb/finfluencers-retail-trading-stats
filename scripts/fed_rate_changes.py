import pandas as pd
import requests
from io import StringIO

# FRED series: Federal Funds Target Range - Upper Limit
FRED_URL = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DFEDTARU"

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
}

print("Downloading FRED rate data...")
res = requests.get(FRED_URL, headers=headers)
df = pd.read_csv(StringIO(res.text))

# Convert date
df["observation_date"] = pd.to_datetime(df["observation_date"])

# Restrict date range
df = df[(df["observation_date"] >= "2020-01-01") & (df["observation_date"] <= "2022-12-31")]

# Compute rate change (difference from previous day)
df["rate_change"] = df["DFEDTARU"].diff()

# Keep only days where rate changed
df_changes = df[df["rate_change"] != 0].copy()

# Label the changes
def classify_change(x):
    if x > 0:
        return "Hike"
    elif x < 0:
        return "Cut"
    else:
        return "Unchanged"

df_changes["action"] = df_changes["rate_change"].apply(classify_change)

# Save CSV
output_path = "fed_rate_changes_2020_2022.csv"
df_changes.to_csv(output_path, index=False)

print(f"Done! Saved rate change events to: {output_path}")
print(df_changes)
