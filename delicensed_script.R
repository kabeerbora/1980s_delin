##Packages
library(arrow)
library(plm)
library(dplyr)
library(mFilter)
library(ggplot2)
library(stringr)

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

##Regression
df_clean <- df_panel %>%
  filter(
    !is.na(rate_of_profit),           
    !is.nan(rate_of_profit),            
    is.finite(rate_of_profit),
    rate_of_profit >= -2,
    rate_of_profit <= 2,
    year >= 1981,
    year <= 1987
  )

did_model_twfe <- plm(
  rate_of_profit ~ delicensed + factor(Year), 
  data = df_clean,
  model = "within", 
  effect = "individual"  
)
summary(did_model_twfe)
summary(did_model_state) 

did_model_state <- plm(
  rate_of_profit ~ delicensed + factor(Year) + factor(State), 
  data = df_clean,
  model = "within",
  effect = "individual"  
)

##Event study

