##Packages
library(arrow)
library(plm)
library(dplyr)
library(mFilter)
library(ggplot2)
library(stringr)
library(fixest)
library(HonestDiD)
library(lmtest)
library(sandwich)
##Read data
library(readr)
setwd("G:/My Drive/data_economics_research/jan_weber_kabeer_bora")
panel_79_88 <- read_csv("panel_79_88.csv")

df <- panel_79_88
View(df) 

##Set panel 
df_panel <- pdata.frame(df, index = c("firm_Id", "Year"))

##Identify the Delicensing sectors

delin <- c(
  274, 269, 268, 267, 266, 265, 262, 261, 260, 252, 251, 250, 248, 247, 246, 245, 243, 241, 242,
  240, 232, 231, 236, 235, 234, 233, 230, 224, 217, 215, 214, 212, 209, 208, 205, 201, 200,
  389, 387, 386, 385, 384, 383, 382, 381, 379, 378, 372, 373, 370, 362, 361, 349, 344, 341, 336, 
  335, 334, 333, 332, 329, 326, 325, 324, 301, 296, 295, 291, 288, 287, 284, 279, 277, 276, 275
)

df_panel$nic_3digit <- as.integer(substr(as.character(df_panel$nic_code), 1, 3))

df_panel$delicensed <- ifelse(
  df_panel$nic_3digit %in% delin & df_panel$year >= 1985,
  1,
  0
)
## create k_formation
df_panel$k_form <- with(df_panel,
                        ifelse(
                          is.na(capital_open) | is.na(capital_closing) | capital_open == 0 | capital_closing == 0,
                          NA,
                          (capital_closing - capital_open) / capital_open
                        )
)
df_panel$rate_surplus <- with(df_panel,
                        ifelse(
                          is.na(tot_emoluments) | is.na(value_added) | tot_emoluments == 0 | value_added == 0,
                          NA,
                          (value_added - tot_emoluments)/tot_emoluments
                        )
)

df_panel$rop_naya <- (df_panel$value_added - df_panel$tot_emoluments)/df_panel$capital_closing


##Regression
df_clean <- df_panel %>%
  filter(
    !is.na(rate_of_profit),           
    !is.nan(rate_of_profit),            
    is.finite(rate_of_profit),
    rop_naya >= -5,
    rop_naya <= 5,
    year >= 1981,
    year <= 1987
  )

did_model_twfe <- plm(
  rate_of_profit ~ delicensed + factor(Year), 
  data = df_clean,
  model = "within", 
  effect = "individual"
)

clust_vcov <- vcovHC(did_model_twfe, type = "HC1", cluster = "group", group = df_clean$nic_code)

coeftest(did_model_twfe, vcov = clust_vcov)
summary(did_model_state) 

did_model_state <- plm(
  rate_of_profit ~ delicensed + factor(Year) + factor(State), 
  data = df_clean,
  model = "within",
  effect = "individual"  
)

did_model_twfe <- plm(
  k_form ~ delicensed + factor(Year), 
  data = df_clean,
  model = "within", 
  effect = "individual"  
)

summary(did_model_twfe)

df_clean$year_state <- interaction(df_clean$Year, df_clean$State, drop = TRUE)
# Step 2: Estimate the model with individual and year × state fixed effects
did_model_twfe_interaction <- plm(
  rop_naya ~ delicensed + factor(year_state),
  data = df_clean,
  model = "within",
  effect = "individual"  # Firm-level fixed effects are still applied here
)

clust_vcov <- vcovHC(did_model_twfe_interaction, type = "HC1", cluster = "group", group = df_clean$nic_code)

coeftest(did_model_twfe_interaction, vcov = clust_vcov)


# Step 3: Summarize the results
summary()


did_model_state <- plm(
  k_form ~ delicensed + factor(Year) + factor(State), 
  data = df_clean,
  model = "within",
  effect = "individual"  
)

summary(did_model_state)

did_model_state <- plm(
  rate_surplus ~ delicensed + factor(Year) + factor(State), 
  data = df_panel,
  model = "within",
  effect = "individual"  
)

summary(did_model_state)


##Event study

df_clean <- df_clean %>%
  mutate(treated = ifelse(nic_3digit %in% delin, 1, 0))

# 2. Construct event time (only for treated firms)
df_clean <- df_clean %>%
  mutate(event_time = ifelse(treated == 1, as.numeric(as.character(Year)) - 1985, NA))

# 3. Cap event time leads/lags at ±5
df_clean <- df_clean %>%
  mutate(event_time_grouped = case_when(
    event_time <= -5 ~ -5,
    event_time >= 5  ~ 5,
    TRUE             ~ event_time
  ))

# 4. Convert to factor and set baseline to period -1
df_clean$event_time_grouped <- factor(df_clean$event_time_grouped)
df_clean$event_time_grouped <- relevel(df_clean$event_time_grouped, ref = "-1")

# 5. Subset data to keep only firms with valid event time (i.e., treated or relevant controls)
df_est <- df_clean %>%
  filter(!is.na(event_time_grouped))

# 6. Estimate the event study DID model
event_study_model <- plm(
  k_form ~ event_time_grouped + factor(Year) + factor(State),
  data = df_est,
  model = "within",
  effect = "individual"
)

# 7. Display summary
summary(event_study_model) 


df_clean <- df_clean %>%
  mutate(treated = ifelse(nic_3digit %in% delin, 1, 0))

# 2. Construct event time (only for treated firms)
df_clean <- df_clean %>%
  mutate(event_time = ifelse(treated == 1, as.numeric(as.character(Year)) - 1985, NA))

# 3. Cap event time leads/lags at ±5
df_clean <- df_clean %>%
  mutate(event_time_grouped = case_when(
    event_time <= -5 ~ -5,
    event_time >= 5  ~ 5,
    TRUE             ~ event_time
  ))

# 4. Convert to factor and set reference period to -1
df_clean$event_time_grouped <- factor(df_clean$event_time_grouped)
df_clean$event_time_grouped <- relevel(df_clean$event_time_grouped, ref = "-1")

# 5. Keep only observations with valid event time
df_est <- df_clean %>%
  filter(!is.na(event_time_grouped))

# 6. Run event study TWFE model
event_study_model <- plm(
  rate_of_profit ~ event_time_grouped + factor(year_state),
  data = df_est,
  model = "within",
  effect = "individual"
)

# 7. Cluster standard errors at the nic_code level
vcov_nic <- vcovHC(event_study_model, type = "HC1", cluster = "group", group = df_est$nic_code)

# 8. Output coefficient table with clustered SEs
coeftest(event_study_model, vcov. = vcov_nic)

beta_hat_all <- coef(event_study_model)

# Select names of event-time dummies (excluding reference category "-1")
event_coef_names <- names(beta_hat_all)[grepl("event_time_grouped", names(beta_hat_all))]
event_coef_names <- event_coef_names[!grepl("event_time_grouped-1", event_coef_names)]

# Extract the event-time coefficients (betas)
beta_hat <- beta_hat_all[event_coef_names]

# --- Step 2: Extract clustered VCV matrix for event-time coefficients only ---
vcov_event <- vcov_nic[event_coef_names, event_coef_names]

# --- Step 4: Run HonestDiD with smoothness restriction (M) ---
# Try a value of M = 0.03
M <- 0.001
vcov_event <- (vcov_event + t(vcov_event)) / 2

# 2. Run HonestDiD
honest_result <- HonestDiD::createSensitivityResults(
  betahat = beta_hat,
  sigma = vcov_event,
  numPrePeriods = 4,
  numPostPeriods = 2,
  M = M
)
# --- Step 5: Visualize results ---
HonestDiD::createSensitivityPlot(honest_result)

print(honest_result)
