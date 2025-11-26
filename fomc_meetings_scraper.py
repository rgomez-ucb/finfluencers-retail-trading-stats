import requests
from bs4 import BeautifulSoup
import pandas as pd

URL = "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm"

print("Fetching webpage...")
resp = requests.get(URL, headers={"User-Agent": "Mozilla/5.0"})
soup = BeautifulSoup(resp.text, "html.parser")

target_years = ["2020", "2021", "2022"]
rows = []

# Step 1 — locate the panels
panels = soup.select("div.panel.panel-default")

print(f"Found {len(panels)} panels...")

for panel in panels:
    # Find the year title
    header = panel.select_one("div.panel-heading h4 a")
    if not header:
        continue
    
    header_text = header.get_text(strip=True)
    
    # Check if this is one of the target years
    year = None
    for y in target_years:
        if y in header_text:
            year = int(y)
            break
    
    if year is None:
        continue
    
    # Step 2 — find all meeting rows inside this panel
    meeting_blocks = panel.select("div.fomc-meeting")

    for block in meeting_blocks:
        month_tag = block.select_one(".fomc-meeting__month strong")
        date_tag = block.select_one(".fomc-meeting__date")

        if not month_tag or not date_tag:
            continue

        month = month_tag.get_text(strip=True)
        date_text = date_tag.get_text(strip=True).replace("*", "")

        # Take first day
        day = date_text.replace("–", "-").split("-")[0].strip()
        date_str = f"{month} {day}, {year}"

        try:
            date_val = pd.to_datetime(date_str)
        except:
            print("Failed to parse:", date_str)
            continue

        rows.append([date_val, month, date_text, year])

df = pd.DataFrame(rows, columns=["date", "month", "raw_date_text", "year"])
df = df.sort_values("date")

df.to_csv("fomc_meetings.csv", index=False)

print("\nSaved: fomc_meetings.csv")
print(df)
