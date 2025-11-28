import os
import glob
import pandas as pd

data_directory = '/Users/ruben/Desktop/Applied-Stats-Prof-Max/Final_Project_Applied_Stats_Max_2025/StockTwits_2020_2022_Raw/AMZN_2019_2022/'

pattern = os.path.join(data_directory, 'AMZN_*.csv')
csv_files = sorted(glob.glob(pattern))

print(f"Found {len(csv_files)} files")
if not csv_files:
    raise SystemExit("No CSV files found in the specified directory."
                        )

dataframes = []
for i, file in enumerate(csv_files):
    print(f"Reading file {i+1}/{len(csv_files)}: {os.path.basename(file)}")
    df = pd.read_csv(file)
    dataframes.append(df)

full_df = pd.concat(dataframes, ignore_index=True)

# save .csv of full merged file
output = os.path.join(data_directory, 'AMZN_ALL_MERGED_2020_2022.csv')
full_df.to_csv(output, index=False)

print(f"\nDone. Saved merged file to:\n{output}")
print(f"Final shape: {full_df.shape}")