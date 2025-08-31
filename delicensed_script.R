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
library(fixest)
library(readxl)
library(modelsummary)


##Read data
library(readr)
setwd("G:/My Drive/data_economics_research/jan_weber_kabeer_bora")
panel_79_88 <- read_csv("panel_79_88.csv")
df <- panel_79_88

price_indices <- read_excel("price_indices.xlsx")
View(price_indices)

base_year <- 2010
base_wpi <- price_indices$wpi[price_indices$year == base_year]
price_indices$wpi_adjust <- base_wpi / price_indices$wpi

df$year <- as.numeric(sub(".*_", "", df$year))

df <- merge(df, price_indices[, c("year", "wpi_adjust")], by = "year", all.x = TRUE)

monetary_vars <- c(
  "capital_open", "capital_closing", "work_cap_open", "work_cap_close",
  "outstanding_open", "outstanding_close", "wages", "tot_output", 
  "value_added", "semi_open", "semi_close", "bonus_workers", 
  "tot_emoluments", "K_formation", "gross_sales"
)

existing_monetary_vars <- monetary_vars[monetary_vars %in% names(df)]
message("Adjusting these variables: ", paste(existing_monetary_vars, collapse = ", "))

for (var in existing_monetary_vars) {
  if (any(!is.na(df[[var]]))) {
    df[[var]] <- round(df[[var]] * df$wpi_adjust, 2)
  } else {
    warning("Skipping '", var, "' - all values are NA")
  }
}

df$wpi_adjust <- NULL

state_classification <- data.frame(
  state_code = c("WEST BENGAL", "GUJARAT", "MAHARASHTRA", "ORISSA",
                 "ANDHRA PRADESH", "KERALA", "RAJASTHAN", "TAMIL NADU", "KARNATAKA",
                 "ASSAM", "BIHAR", "HARYANA", "PUNJAB", "UTTAR PRADESH", "JAMMU & KASHMIR"),
  pro_worker = c(1, 1, 1, 1, 
                 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0),
  pro_employer = c(0, 0, 0, 0,
                   1, 1, 1, 1, 1,
                   0, 0, 0, 0, 0, 0),
  neutral = c(0, 0, 0, 0,
              0, 0, 0, 0, 0,
              1, 1, 1, 1, 1, 1)
)


df <- df %>%
  left_join(state_classification, by = "state_code") %>%
  # Ensure all other variables are preserved
  relocate(names(state_classification)[-1], .after = state_code)


panel_79_88 <- read_csv("panel_with_unique_ids.csv")
df <- panel_79_88
View(df)
colnames(df)

colnames(df)[colnames(df) == "plant_id"] <- "firm_Id"
df$Year <- sub("_.*", "", df$year)
 
##Set panel 
df_panel <- pdata.frame(df, index = c("firm_Id", "Year"))
df_panel <- df_panel[df_panel$ownership_code_unique == 1, ]
df_panel$large <- ifelse(df_panel$persons_engaged >= 100, 1, 0)

unique(df_panel$ownership_code_unique)

## Adjust monetary variables


##Identify the Delicensing sectors

delin <- c(
  274, 269, 268, 267, 266, 265, 262, 261, 260, 252, 251, 250, 248, 247, 246, 245, 243, 241, 242,
  240, 232, 231, 236, 235, 234, 233, 230, 224, 217, 215, 214, 212, 209, 208, 205, 201, 200,
  389, 387, 386, 385, 384, 383, 382, 381, 379, 378, 372, 373, 370, 362, 361, 349, 344, 341, 336, 
  335, 334, 333, 332, 329, 326, 325, 324, 301, 296, 295, 291, 288, 287, 284, 279, 277, 276, 275
)

df_panel$nic_3digit <- as.integer(substr(as.character(df_panel$nic_code), 1, 3))
df_panel$Year <- as.numeric(as.character(df_panel$Year))
df_panel$delicensed <- ifelse(
  df_panel$nic_3digit %in% delin & df_panel$Year >= 1985,
  1,
  0
)

delicensed_by_year <- df_clean %>%
  filter(!is.na(delicensed)) %>%  # Ensure no NA values in delicensed
  group_by(Year) %>%
  summarise(
    num_delicensed = sum(delicensed, na.rm = TRUE),
    total_firms = n(),
    .groups = "drop"
  )

print(delicensed_by_year)

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

df_clean <- df_panel %>%
  mutate(Year = as.numeric(as.character(Year))) %>%  # Convert Year to numeric
  filter(
    !is.na(rate_of_profit),
    !is.nan(rate_of_profit),
    is.finite(rate_of_profit),
    rate_of_profit >= -5,
    rate_of_profit <= 5,
    Year >= 1979,
    Year <= 1986
  )


## Averages of rate of profit by category
df_clean <- df_clean %>%
  mutate(
    delin_group = nic_3digit %in% delin
  )

df$nic_3digit <- as.integer(substr(as.character(df$nic_code), 1, 3))

## Firms by treatment (har saal ka)
firms_by_year <- df %>%
  group_by(year, delin_group) %>%
  summarise(
    n_firms = mean(year_initial, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(delin_group_label = ifelse(delin_group, "Delicensed", "Non-Delicensed"))

print(firms_by_year)


df_clean$state_code_numeric <- as.numeric(as.factor(df_clean$state_code))

df_clean <- df_clean %>%
  mutate(state_code_numeric = as.numeric(factor(state_code)))

## No State Trends DiD

did_model_k_baseline <- feols(
  k_form ~ delicensed | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_k_persons <- feols(
  k_form ~ delicensed + persons_engaged | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_k_all <- feols(
  k_form ~ delicensed + persons_engaged + gross_sales | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_k_baseline)
summary(did_model_k_persons)
summary(did_model_k_all)
summary(did_model_profit_baseline)
summary(did_model_profit_persons)
summary(did_model_profit_all)


# Rate of Profit models
did_model_profit_baseline <- feols(
  rate_of_profit ~ delicensed | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_profit_persons <- feols(
  rate_of_profit ~ delicensed + persons_engaged | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_profit_all <- feols(
  rate_of_profit ~ delicensed + persons_engaged + gross_sales | 
    firm_Id + state_code + Year,
  data = df_clean,
  cluster = ~nic_3digit
)



## Full model for rate_of_profit with all covariates and state trends
did_model_7 <- feols(
  rate_of_profit ~ delicensed + gross_sales + persons_engaged | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Remove gross_sales for rate_of_profit
did_model_8 <- feols(
  rate_of_profit ~ delicensed + persons_engaged | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Model 9: Remove persons_engaged for rate_of_profit (only delicensed)
did_model_9 <- feols(
  rate_of_profit ~ delicensed | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Model 10: Full model for k_form with all covariates and state trends
did_model_10 <- feols(
  k_form ~ delicensed + gross_sales + persons_engaged | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Model 11: Remove gross_sales for k_form
did_model_11 <- feols(
  k_form ~ delicensed + persons_engaged | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Model 12: Remove persons_engaged for k_form (only delicensed)
did_model_12 <- feols(
  k_form ~ delicensed | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_7)
summary(did_model_8)
summary(did_model_9)
summary(did_model_10)
summary(did_model_11)
summary(did_model_12)


### Surplus Value

df_clean$delicensed_lag <- ifelse(
  df_clean$nic_3digit %in% delin & df_clean$Year >= 1986,
  1,
  0
)

did_model_surplus_1 <- feols(
  rate_surplus ~ delicensed + gross_sales + persons_engaged| 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_surplus_2 <- feols(
  rate_surplus ~ delicensed + gross_sales + persons_engaged| 
    firm_Id + state_code + year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_surplus_3 <- feols(
  rate_surplus ~ delicensed_lag + gross_sales + persons_engaged| 
    firm_Id + state_code + year,
  data = df_clean,
  cluster = ~nic_3digit
)

did_model_surplus_4 <- feols(
  rate_surplus ~ delicensed_lag + gross_sales + persons_engaged| 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_surplus_1)
summary(did_model_surplus_2)
summary(did_model_surplus_3)
summary(did_model_surplus_4)


df_clean$treated <- ifelse(df_clean$nic_3digit %in% delin, 1, 0)

# Event-study for rate_of_profit

did_model_10_event_profit <- feols(
  rate_of_profit ~ i(Year, treated, ref = "1984") + persons_engaged + gross_sales| 
    firm_Id + state_code + Year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_10_event_profit)

did_model_10_event_k <- feols(
  k_form ~ i(Year, treated, ref = "1984") + persons_engaged + gross_sales| 
    firm_Id + state_code + Year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_10_event_k)

did_model_10_event_surplus <- feols(
  rate_surplus ~ i(Year, treated, ref = "1985") + persons_engaged + gross_sales| 
    firm_Id + state_code + Year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_10_event_surplus)

## Besley & Burgess

did_model_13 <- feols(
  k_form ~ delicensed + delicensed*pro_employer + delicensed*pro_worker + gross_sales + persons_engaged| 
    firm_Id + state_code + year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_13)

did_model_14 <- feols(
  rate_of_profit ~ delicensed + delicensed*pro_employer + delicensed*pro_worker + gross_sales + persons_engaged| 
    firm_Id + state_code + year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_14)


did_model_15 <- feols(
  rate_surplus ~ delicensed + delicensed*pro_employer + delicensed*pro_worker + gross_sales + persons_engaged| 
    firm_Id + state_code + year + Year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

summary(did_model_15)
