# =======================================================
# Step 0: Robust Package Installation & Loading
# =======================================================
# This section ensures all required packages are installed and loaded correctly.
# It fixes the "function %>% not found" error.

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
# In R, backslashes '\' must be replaced with forward slashes '/' or double backslashes '\\'.
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

# 5. Merge Dataframes into Panel Data format
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
  
  # Define the Event Date (GameStop Short Squeeze Peak)
  cutoff_date <- as.Date("2021-01-28") 
  
  # Create Dummy Variables
  # Post: 1 if date is on or after the event, 0 otherwise
  panel_data_clean$Post <- ifelse(panel_data_clean$date >= cutoff_date, 1, 0)
  
  # Treat: 1 if AAPL (Treatment Group), 0 if AMZN (Control Group)
  panel_data_clean$Treat <- ifelse(panel_data_clean$Ticker == "AAPL", 1, 0)
  
  # DiD: Interaction term (Post * Treat) - This captures the Causal Effect
  panel_data_clean$DiD <- panel_data_clean$Post * panel_data_clean$Treat
  
  # Log-transform variables to normalize distribution
  # Adding 1 to Volume to handle potential zeros (though rare in major stocks)
  panel_data_clean$ln_Volume <- log(panel_data_clean$Volume + 1)
  panel_data_clean$ln_VIX <- log(panel_data_clean$vix_VIXCLS)
  
  # =======================================================
  # Step 4: Run Regression Models
  # =======================================================
  
  # Model 1: OLS with Control Variables (No Fixed Effects)
  # This shows the impact of macro variables explicitly.
  did_model_ctrl <- feols(ln_Volume ~ DiD + Post + Treat + 
                            net_sentiment + ln_VIX + unemp_UNEMPLOY + sofr,
                          data = panel_data_clean,
                          vcov = "hetero")
  
  # Model 2: Two-Way Fixed Effects (TWFE) - Recommended for Academic Papers
  # Includes Ticker Fixed Effects (individual time-invariant characteristics)
  # Includes Date Fixed Effects (absorbs all daily macro shocks like VIX, SOFR, etc.)
  # Note: Macro vars (VIX, SOFR) will be dropped due to collinearity with Date FE.
  did_model_twfe <- feols(ln_Volume ~ DiD + net_sentiment + ln_VIX + unemp_UNEMPLOY + sofr | 
                            Ticker + date, 
                          data = panel_data_clean,
                          vcov = "hetero")
  
  # =======================================================
  # Step 5: Output Results
  # =======================================================
  
  print("--- Regression Results ---")
  
  # Display results in the console
  print(etable(did_model_ctrl, did_model_twfe,
               headers = c("With Controls (OLS)", "TWFE (Preferred)"),
               signif.code = c("***"=0.01, "**"=0.05, "*"=0.1),
               digits = 3))
  
  # Optional: Export to HTML file for Word/Reports
  # stargazer(did_model_twfe, type = "html", out = "DiD_Results.html")
  
} else {
  print("Error: The dataset is empty after cleaning. Please check source data.")
}