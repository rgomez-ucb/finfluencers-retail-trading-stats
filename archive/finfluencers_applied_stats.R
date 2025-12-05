# install.packages(c("tidyverse","lubridate","tidyquant","fixest","fredr))
library(tidyverse)
library(lubridate)
library(tidyquant)
library(fixest)
library(fredr) #install 


#----------Stock–day data----------
tickers <- c("GME","AMC","PLTR","CVNA")  # starting with a small number of stocks. we can add more later on
                                        # GME,gamestop, AMC,movie theater, PLTR, Palantir, CVNA, Carvana  

start_date <- as.Date("2020-01-01")
end_date   <- as.Date("2024-12-31")

px <- tq_get(tickers, get = "stock.prices",
             from = start_date, to = end_date) %>%
  transmute(
    stock = symbol,
    date,
    close_price_usd = adjusted,
    trading_volume_shares = volume
  )

#----------Simple market volatility control (VIX) – placeholder as a random series here----------
# In the real version you replace this with FRED VIXCLS.
fredr_set_key("FRED_API_KEY")
calendar <- tibble(date = seq.Date(start_date, end_date, by = "day")) %>%
  filter(wday(date, label = TRUE) %in% c("Mon","Tue","Wed","Thu","Fri"))

set.seed(1)
macro <- calendar %>%
  mutate(VIX = pmax(10, 20 + rnorm(n(), 0, 5)))  # plug in real VIX later

#=--------- instad of using the API--------
unemployment.csv <- "path"

unemployment_data <- read_csv(unemployment.csv)

# clean csv
vix_raw <- viz_raw %>%
  transmute(
    data = as.Date(DATE), 
    VIX = as.numeric(VIXCLS)
  ) %>%
  filter(!is.na(VIX))

#----------Finfluencer events (sample, we need to get these dates and timestamps)----------
influencer_events <- tribble(
  ~stock, ~recommendation_datetime, ~influencer,
  "GME",  ymd_hms("2024-05-13 09:00:00"), "Roaring Kitty",
  "AMC",  ymd_hms("2021-06-02 09:30:00"), "Matt Kohrs",
  "PLTR", ymd_hms("2023-11-03 10:00:00"), "Meet Kevin"
)


#----------Build RecEvent and event_time----------
# One-day dummy: RecEvent
recs_daily <- influencer_events %>%
  transmute(stock,
            date = as_date(recommendation_datetime),
            RecEvent = 1L)

# ----------Merge with API data----------
panel <- px %>%
  left_join(macro, by = "date") %>%
  left_join(recs_daily, by = c("stock","date")) %>%
  mutate(
    RecEvent = replace_na(RecEvent, 0L),
    log_volume = log1p(trading_volume_shares)
  ) %>%
  arrange(stock, date)

#-----------merge with .csv data
# Merge into panel
panel <- panel %>%
  left_join(recs_daily, by = c("stock","date")) %>%
  mutate(RecEvent = replace_na(RecEvent, 0L))

# 2) event_time (for event study)
panel <- panel %>%
  left_join(
    influencer_events %>%
      transmute(stock, event_date = as.Date(recommendation_datetime)),
    by = "stock"
  ) %>%
  mutate(event_time = as.integer(date - event_date))

# ----------event_time: for each stock with an event, compute days from event
panel <- panel %>%
  left_join(
    influencer_events %>% transmute(stock, event_date = as_date(recommendation_datetime)),
    by = "stock"
  ) %>%
  mutate(
    event_time = as.integer(date - event_date)
  )

# ----------baskline panel regression (basic)----------
m_baseline <- feols(
  log_volume ~ RecEvent + VIX | stock + month(date),
  cluster = ~stock,
  data = panel
)
summary(m_baseline)

# ----------EVent study----------
# keep only observations in a window around events, e.g. [-10, +10]
panel_es <- panel %>%
  filter(!is.na(event_time),
         event_time >= -10, event_time <= 10)

m_event <- feols(
  log_volume ~ i(event_time, ref = -1) + VIX | stock,
  cluster = ~stock,
  data = panel_es
)

summary(m_event)
iplot(m_event, main = "Event-study: Volume Around Finfluencer Posts")

# ----------Rows to inspect----------
panel %>%
  filter(stock %in% c("GME","PLTR")) %>%
  slice_head(n = 10) %>%
  select(stock, date, close_price_usd, trading_volume_shares,
         RecEvent, event_time, VIX, log_volume)
