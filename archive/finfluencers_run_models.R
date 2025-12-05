# =======================================================
# Step 0: Intelligent Package Installation & Loading
# =======================================================
# This section ensures all required packages are installed and loaded.
# It fixes common errors like "function %>% not found".

packages_needed <- c("tidyverse", "fixest", "lubridate", "stargazer")

for (pkg in packages_needed) {
  # Check if package is installed; if not, install it.
  if (!require(pkg, character.only = TRUE)) {
    print(paste("Installing package:", pkg))
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  } else {
    print(paste("Package loaded:", pkg))
  }
}

# Explicitly load dplyr to ensure the pipe operator '%>%' works
library(dplyr)

print("Setup complete. Starting analysis...")

# =======================================================
# Step 1: Read Data
# =======================================================
# Note: Ensure the file path is correct. 
# Windows paths need forward slashes '/' or double backslashes '\\'.
file_path <- "D:/zhannie/2025-2026 UCB MaCSS/fall course/advanced applied statistics/finfluencers-retail-trading-stats/final_merged_data.csv"

# Read the CSV file
df <- read.csv(file_path)

# Convert the date column to Date object
df$date <- as.Date(df$date)

# =======================================================
# Step 2: Data Cleaning & Preparation
# =======================================================

# 1. Identify and Rename the SOFR Column
# Logic: Find columns containing "sofr_Rate" but exclude "Type" (which is text).
all_sofr_cols <- grep("sofr_Rate", colnames(df), value = TRUE)
real_sofr_col <- all_sofr_cols[!grepl("Type", all_sofr_cols)][1]

print(paste("Selected SOFR column:", real_sofr_col))

# Rename the identified column to "sofr" for easier access
colnames(df)[colnames(df) == real_sofr_col] <- "sofr"

# 2. Define a Robust Numeric Cleaning Function
# This removes commas "," and percentage signs "%" before converting to numeric.
clean_numeric_robust <- function(x) {
  suppressWarnings(as.numeric(gsub("[%,]", "", as.character(x))))
}

# 3. Process AAPL Data
df_aapl <- df %>%
  select(date, starts_with("aapl"), net_sentiment, vix_VIXCLS, unemp_UNEMPLOY, sofr) %>%
  mutate(Ticker = "AAPL") %>%
  rename_with(~ str_remove(., "aapl_"), starts_with("aapl")) %>%
  # Apply cleaning function to all price, volume, and macro columns
  mutate(across(c(Open, High, Low, Close, Adj.Close, Volume, sofr, net_sentiment), clean_numeric_robust))

# 4. Process AMZN Data
df_amzn <- df %>%
  select(date, starts_with("amzn"), net_sentiment, vix_VIXCLS, unemp_UNEMPLOY, sofr) %>%
  mutate(Ticker = "AMZN") %>%
  rename_with(~ str_remove(., "amzn_"), starts_with("amzn")) %>%
  mutate(across(c(Open, High, Low, Close, Adj.Close, Volume, sofr, net_sentiment), clean_numeric_robust))

# 5. Merge Dataframes into Panel Data format (Wide to Long)
panel_data <- bind_rows(df_aapl, df_amzn)

# 6. Fill Missing Macro Values (Down-fill)
# Macro data (like unemployment or rates) might be missing on weekends/holidays.
panel_data <- panel_data %>%
  arrange(date) %>%
  fill(sofr, .direction = "down") %>%
  fill(unemp_UNEMPLOY, .direction = "down") %>%
  fill(vix_VIXCLS, .direction = "down")

# 7. Drop Invalid Rows
# Remove rows where Volume, Close, SOFR, or Sentiment are still NA.
panel_data_clean <- panel_data %>% 
  drop_na(Volume, Close, sofr, net_sentiment)

print(paste("Number of observations remaining after cleaning:", nrow(panel_data_clean)))

# =======================================================
# Step 3: Construct DiD Variables
# =======================================================

if(nrow(panel_data_clean) > 0) {
  
  # Define the Event Date (GameStop Short Squeeze / Finfluencer Peak)
  cutoff_date <- as.Date("2021-01-28") 
  
  # --- Variables for Binary DiD (AAPL vs AMZN) ---
  # Post: 1 if date is on or after the event, 0 otherwise
  panel_data_clean$Post <- ifelse(panel_data_clean$date >= cutoff_date, 1, 0)
  
  # Treat: 1 if AAPL (Treatment Group), 0 if AMZN (Control Group)
  panel_data_clean$Treat <- ifelse(panel_data_clean$Ticker == "AAPL", 1, 0)
  
  # Binary DiD Interaction: (Post * Treat)
  panel_data_clean$DiD <- panel_data_clean$Post * panel_data_clean$Treat
  
  # --- Variables for Continuous DiD (Sentiment Based) ---
  # Assumption: After the event, high sentiment drives volume more strongly.
  # We do not strictly separate AAPL/AMZN, but use Sentiment intensity.
  panel_data_clean$Continuous_DiD <- panel_data_clean$Post * panel_data_clean$net_sentiment
  
  # Log-transform variables (Standard practice for financial volume data)
  panel_data_clean$ln_Volume <- log(panel_data_clean$Volume + 1)
  panel_data_clean$ln_VIX <- log(panel_data_clean$vix_VIXCLS)
  
  # =======================================================
  # Step 4: Run Regression Models
  # =======================================================
  
  # Model 1: Binary DiD - OLS with Control Variables
  # Purpose: To see the explicit effect of macro variables like VIX and SOFR.
  did_model_ctrl <- feols(ln_Volume ~ DiD + Post + Treat + 
                            net_sentiment + ln_VIX + unemp_UNEMPLOY + sofr,
                          data = panel_data_clean,
                          vcov = "hetero")
  
  # Model 2: Binary DiD - Two-Way Fixed Effects (TWFE)
  # Purpose: Standard academic model. Controls for Ticker and Date fixed effects.
  # Note: Macro variables (VIX, SOFR) are absorbed by Date Fixed Effects.
  did_model_twfe <- feols(ln_Volume ~ DiD + net_sentiment + ln_VIX + unemp_UNEMPLOY + sofr | 
                            Ticker + date, 
                          data = panel_data_clean,
                          vcov = "hetero")
  
  # Model 3: Continuous DiD (Advanced)
  # Purpose: Resolves the issue that "AMZN might also be affected".
  # Uses 'net_sentiment' as the treatment intensity.
  did_model_continuous <- feols(ln_Volume ~ Continuous_DiD + net_sentiment | 
                                  Ticker + date, 
                                data = panel_data_clean,
                                vcov = "hetero")
  
  # =======================================================
  # Step 5: Output Results
  # =======================================================
  
  print("--- Regression Results ---")
  
  # Display results in the console
  # 'did_model_twfe' is the standard DiD result.
  # 'did_model_continuous' is the robustness check result.
  print(etable(did_model_ctrl, did_model_twfe, did_model_continuous,
               headers = c("Binary DiD (OLS)", "Binary DiD (TWFE)", "Continuous DiD"),
               signif.code = c("***"=0.01, "**"=0.05, "*"=0.1),
               digits = 3))
  
} else {
  print("Error: The dataset is empty after cleaning. Please check source data.")
}