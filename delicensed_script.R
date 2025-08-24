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

df_panel$rop_naya <- (df_panel$value_added - df_panel$wages)/df_panel$capital_open
df_panel$rate_of_profit <- (df_panel$value_added - df_panel$tot_emoluments)/df_panel$capital_open

View(df_panel)

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
df_clean <- df_panel %>%
  filter(
    !is.na(rate_of_profit),           
    !is.nan(rate_of_profit),            
    is.finite(rate_of_profit),
    rate_of_profit >= -2,
    rate_of_profit <= 2,
    year >= 1981,
    year <= 1988
  )


## K_form DiD

did_model_1 <- feols(
  k_form ~ delicensed| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_1)

did_model_2 <- feols(
  rate_of_profit ~ delicensed + gross_sales + persons_engaged| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_2)


did_model_3 <- feols(
  k_form ~ delicensed + year_initial + persons_engaged| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_3)

## RoP DiD

did_model_4 <- feols(
  rate_of_profit ~ delicensed| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_4)

did_model_5 <- feols(
  rate_of_profit ~ delicensed + year_initial| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_5)

did_model_2 <- feols(
  rate_of_profit ~ delicensed + gross_sales + persons_engaged + state_code:factor(year) | 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_2)

did_model_6 <- feols(
  rate_of_profit ~ delicensed + year_initial + persons_engaged| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_6)


unique_state_codes <- unique(df_clean$state_code)

## rate of surplus value regressions

did_model_1 <- feols(
  rate_surplus ~ delicensed + year_initial + persons_engaged| 
    firm_Id + state_code + year, 
  data = df_clean, 
  cluster = ~nic_3digit
)

summary(did_model_1)


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

View(df_clean)
df_clean <- df_clean %>%
  mutate(
    category = case_when(
      pro_worker == 1 ~ "pro_worker",
      pro_employer == 1 ~ "pro_employer",
      neutral == 1 ~ "neutral",
      TRUE ~ "other"
    )
  )

mean_by_year_category <- df_clean %>%
  group_by(year, category) %>%
  summarise(
    mean_value = mean(rate_of_profit, na.rm = TRUE),
    .groups = "drop"
  )
View(mean_by_year_category)

# Merge with main dataframe while preserving all variables
df <- df %>%
  left_join(state_classification, by = "state_code") %>%
  # Ensure all other variables are preserved
  relocate(names(state_classification)[-1], .after = state_code)

# Capital Formation Model
model_bb_1 <- feols(
  rate_of_profit ~ delicensed + 
    delicensed*pro_worker + 
    delicensed*pro_employer +
    persons_engaged| 
    firm_Id + state_code + year,
  data = df_clean,
  cluster = ~nic_code
)

summary(model_bb_1)

model_bb_2 <- feols(
  k_form ~ delicensed + 
    delicensed*pro_worker + 
    delicensed*pro_employer +
    persons_engaged | 
    firm_Id + state_code + year,
  data = df_clean,
  cluster = ~nic_code
)

summary(model_bb_2) 


df_clean <- df_clean %>%
  mutate(size_quartile = ntile(persons_engaged, 10))

model_size <- feols(
  rate_of_profit ~ delicensed + 
    delicensed:size_quartile| 
    firm_Id + state_code + year,
  data = df_clean,
  cluster = ~nic_code
)

model_trends <- feols(
  log(value_added/persons_engaged) ~ delicensed + 
    delicensed:pro_worker + 
    delicensed:pro_employer| 
    firm_Id + state_code[year] + year,  # State-specific trends
  data = df_clean,
  cluster = ~nic_code
)

summary(model_trends)

event <- feols(
  rate_of_profit ~ i(year, pro_worker, ref = 1984) | 
    firm_Id + state_code[year],
  data = filter(df_clean, year <= 1985), # Pre-treatment only
  cluster = ~nic_code
)

## Averages of rate of profit by category
df_clean <- df_clean %>%
  mutate(
    delin_group = nic_3digit %in% delin
  )

# Compute mean rate of profit by delin group
profit_by_year <- df_clean %>%
  group_by(year, delin_group) %>%
  summarise(
    mean_profit_rate = median(rate_of_profit, na.rm = TRUE),
    n_firms = n_distinct(firm_Id, na.rm = TRUE),
    n_rows = n(),
    .groups = "drop"
  ) %>%
  mutate(delin_group_label = ifelse(delin_group, "Delicensed", "Non-Delicensed"))

# Print results
cat("\nAverage Rate of Profit by Year and Delin Group:\n")
print(profit_by_year)

kform_by_year <- df_clean %>%
  group_by(year, delin_group) %>%
  summarise(
    mean_k_form = median(k_form, na.rm = TRUE),
    n_firms = n_distinct(firm_Id, na.rm = TRUE),
    n_rows = n(),
    .groups = "drop"
  ) %>%
  mutate(delin_group_label = ifelse(delin_group, "Delicensed", "Non-Delicensed"))

print(kform_by_year)

View(df)

df <- df %>%
  mutate(
    delin_group = nic_3digit %in% delin
  )

df$nic_3digit <- as.integer(substr(as.character(df$nic_code), 1, 3))

firms_by_year <- df %>%
  group_by(year, delin_group) %>%
  summarise(
    n_firms = mean(year_initial, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(delin_group_label = ifelse(delin_group, "Delicensed", "Non-Delicensed"))

print(firms_by_year)


rosv_by_year <- df_clean %>%
  group_by(year, delin_group) %>%
  summarise(
    mean_rosv = mean(year_initial, na.rm = TRUE),
    n_firms = n_distinct(firm_Id, na.rm = TRUE),
    n_rows = n(),
    .groups = "drop"
  ) %>%
  mutate(delin_group_label = ifelse(delin_group, "Delicensed", "Non-Delicensed"))

print(rosv_by_year)

# Model 7: Full model for rate_of_profit with all covariates and state trends
# Convert state_code to numeric
df_clean$state_code_numeric <- as.numeric(as.factor(df_clean$state_code))

# Run the model with the numeric state_code
# Ensure state_code_numeric exists as a numeric variable
df_clean <- df_clean %>%
  mutate(state_code_numeric = as.numeric(factor(state_code)))

# Model 7: Full model for rate_of_profit with all covariates and state trends
did_model_7 <- feols(
  rate_of_profit ~ delicensed + gross_sales + persons_engaged | 
    firm_Id + state_code + year + year[state_code_numeric],
  data = df_clean,
  cluster = ~nic_3digit
)

# Model 8: Remove gross_sales for rate_of_profit
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

modelsummary(list(
  "Profit (Full)" = did_model_7,
  "Profit (No Sales)" = did_model_8,
  "Profit (Only Delicensed)" = did_model_9,
  "K (Full)" = did_model_10,
  "K (No Sales)" = did_model_11,
  "K (Only Delicensed)" = did_model_12
), 
stars = TRUE,
gof_map = c("nobs", "r.squared", "within.r.squared")
)

