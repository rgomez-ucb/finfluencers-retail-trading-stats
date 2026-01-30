# Finfluencer Effect on Retail Investment Behavior
Repo that statistically measures financial social media influencer impact on retail trading

Contributors: Gao Kaia, Gomez Ruben, Zhou Hanning

[View the Full Presentation (PDF)](finfluencer_presentation.pdf)

### 1. Research Question

Question of interest: What factors determine movement of a stock price?<br>
Y variable: Trading volume<br>
Right hand variable: Net Sentiment of Finfluencers <br>
Control: Market return, VIX, unemployment rates, percentage of bankruptcy, Federal Reserve interest rate decisions<br>

**Research Question:**
Does lagged retail sentiment influence next-day stock trading volume?

**Testable hypothesis:**
 Retail Sentiment Effect<br>
H1: Lagged retail sentiment negatively predicts next-day trading volume.<br>
H0: Lagged retail sentiment has no effect on next-day trading volume.<br>

### 2. Data Description
| Variable Type        | Variable Name | Symbol     | Definition / Formula             | Economic Proxy                     |
|----------------------|---------------|------------|----------------------------------|-------------------------------------|
| **Dependent**        | Log Volume    | $Y_{it}$ | $\log(Volume_t)$               | Trading Activity / Liquidity        |
| **Predictor**        | Net Sentiment | $X_{1, i,t-1}$ | $(Bull - Bear) / Total$     | Retail Optimism vs. Pessimism       |
| **Control (Social)** | Log Buzz      | $X_{2, i,t-1}$ | $\log(NewsCount)$            | Retail Attention / Noise            |
| **Control (Market)** | Volatility    | $X_{3, i,t-1}$ | $(High - Low) / Open$        | Uncertainty / Opinion Divergence    |
| **Control (Market)** | Abs Return    | $X_{4, i,t-1}$ | Abs Return           | $Ret_{t-1}$             |
| **Control (Macro)**  | Risk Appetite | $Z_{1, t}$    | AAII Bull–Bear Spread          | Market-wide Fear / Greed            |
| **Control (Macro)**  | Fed Rate      | $Z_{2, t}$    | Effective Fed Funds Rate       | Cost of Capital                     |
| **Control (Macro)**  | Unemployment  | $Z_{3, t}$    | U.S. Unemployment Rate         | Economic Health / Labor Market      |
| **Control (Macro)**  | FOMC Dummy    | $Z_{4, t}$    | 1 if FOMC day, else 0          | Policy Event Shock                  |



#### Sample Composition
Stocks: AAPL, AMZN, FB, NVDA, TSLA.<br>
Period: 2020-01-06 to 2022-02-25 (541 trading days per stock).<br>
Structure: Perfectly Balanced Panel (No missing values).<br>

#### Key Observations:

##### The "Buzz" Disparity: 
There is a massive structural difference in social attention. FB generates ~65x more daily discussion posts than NVDA, yet NVDA has higher trading volume (Log 19.77 vs 16.80). This confirms that raw discussion count is not a direct proxy for liquidity and necessitates the use of Log_Buzz and Entity Fixed Effects in our regression.
##### Sentiment Polarization:
TSLA and AAPL have the lowest mean sentiment (~0.48), suggesting these stocks experience more "Bear vs. Bull" debates compared to NVDA (0.67), which enjoyed strong consensus optimism during this period.<br>
##### Volatility Profile:
TSLA is the clear outlier in risk, with an average intraday range of 5.19%, significantly higher than the stable mega-caps (AAPL/AMZN).<br>

### 3. Regression Model Specification
To account for the extreme heterogeneity observed above... Entity Fixed Effects ($\alpha_i$).

$$
\log(Volume_{it}) = \alpha_i + \beta_1 Sentiment_{it-1} + \beta_2 \log(Social_{it-1}) + \beta_3 Market_{it-1} + \beta_4 Macro_t + \varepsilon_{it}
$$

- Fixed Effects: Absorb the baseline differences (e.g., controlling for the fact that FB naturally has more posts than NVDA).
- Lagged variables: prevent 'Look-ahead Bias'.
- Clustered Standard Errors: Used to correct for serial correlation within stocks.


### 4. Empirical Results & Interpretation
Based on the regression output from this dataset:
#### A. The "Negativity Bias" (Retail Fear)
Coefficient: Negative and Significant.<br>
Finding: We observe that lower Net Sentiment (more bearishness) predicts higher trading volume.<br>
Context: TSLA and AAPL, which have the lowest average sentiment (0.48), are highly liquid. This supports the hypothesis that retail investors are more active during periods of disagreement or fear (panic selling) than during periods of consensus optimism.<br>
#### B. The Role of Volatility
Finding: Intraday Range (Volatility_Lag1) is the single strongest predictor (t > 10).<br>
Context: TSLA's high volatility (5.19%) naturally correlates with its high trading interest. The model confirms that price action drives trading volume: when the intraday range widens, volume follows immediately.<br>
#### C. Macro Sensitivity
Finding: The RiskAppetite variable (Macro Fear) remains significant.<br>
Context: Just as stock-specific fear drives volume, macro-level fear (low risk appetite) drives volume across all 5 tickets.

### 5. Conclusion
The final conclusion remains robust: Trading volume in the tech sector is driven by Price Volatility and Fear (Negative Sentiment), rather than raw social media noise (Buzz).


