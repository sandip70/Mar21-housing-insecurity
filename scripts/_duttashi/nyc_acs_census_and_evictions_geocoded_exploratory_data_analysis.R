# Exploratory Data analysis for housing insecurity
# Objective: To determine variables relevant to hosuing insecurity prediction
# required data files: nyc_acs5-2018_census.csv, nyc_evictions_geocoded.csv
# Script author: Ashish Dutt
# Script create date: 02/3/2021
# Script last modified date: 04/3/2021
# Email: ashish.dutt8@gmail.com

# clean the workspace
rm(list = ls())

# required libraries
library(tidyverse) # for data manipulation
library(data.table) # for setnames()

# read the raw dataset in memory
df_nycacs_raw <- read.csv("data/acs/nyc_acs5-2018_census.csv", na.strings = NA)
df_nycevict_raw <- read.csv("data/raw/nyc_evictions_geocoded.csv", na.strings = NA)

# 1. Exploratory Data Analysis

# 1.1. check data dimension
dim(df_nycacs_raw) # 2167 rows in 1034 cols
dim(df_nycevict_raw) # [1] 60788 rows in  23 cols

# 1.2. check for missing data
sum(is.na(df_nycacs_raw)) # 0 missing values
sum(is.na(df_nycevict_raw)) # [1] 26645 missing values
colSums(is.na(df_nycevict_raw))

# 1.3 Find variables with zero variance
excluded_vars  <- df_nycacs_raw %>%
  summarise_all(var) %>%
  select_if(function(.) . == 0) %>% 
  names() ## Finding: 50 variables with zero variance 

# remove the 50 variables with zero variance
df_nycacs_raw<- df_nycacs_raw %>%
  select(-one_of(excluded_vars))
dim(df_nycacs_raw) # [1] 2167  984

# remove missing data from df_nycevict_raw dataframe
df_nycevict_raw <- df_nycevict_raw %>%
  drop_na()
colSums(is.na(df_nycevict_raw))
# write clean nyc geocoded data to disk
write.csv(df_nycevict_raw, file =  "data//_volunteer_created_datasets//df_nycevict_raw.csv")

# Data Engineering

## 1. Creating new columns
df_nycacs_raw <- df_nycacs_raw %>%
  mutate(newcol = str_extract(index, "\\> tract:[0-9]+"))%>%
  mutate(tract_code = str_extract(newcol,"[0-9]+")) %>%
  unnest(index) %>%
  unique
# drop irrelevant cols
df_nycacs_raw$newcol<- NULL

# Cleaning the nvc eviction geocoded data

# clean the EXECUTED_DATE variable
table(df_nycevict_raw$EXECUTED_DATE) # Observation: date is in month/day/year format

df_nycevict_raw<- df_nycevict_raw %>%
  # split variable executed_date into day,month, year cols
  separate(EXECUTED_DATE, into = c("executed_month", 
                                   "executed_day", 
                                   "executed_year"), sep = "/") %>%
  separate(lon_lat, into = c("lon", "lat"), sep=",")

table(df_nycevict_raw$executed_year) # Observation: data from year 2017 to 2020. One garbage value of 70
# remove the year 70 value from executed_year
df_nycevict_raw<- df_nycevict_raw %>%
  filter(!(executed_year=="70"))
table(df_nycevict_raw$executed_year)
# Observation: The year in variable `executed_year` has the format of 1,2,3...12.
# Replace it with 2001,2002,2003...,2012
df_nycevict_raw$executed_month <- plyr::revalue(df_nycevict_raw$executed_month,
                                               c("1"="Jan","2"="Feb","3"="Mar","4"="Apr","5"="May",
                                                 "6"="Jun","7"="Jul","8"="Aug","9"="Sept","10"="Oct",
                                                 "11"="Nov","12"="Dec"))
# I find the variable tract_code is common in both nyc eviction data and nyc acs raw data
df_nycevict_raw$tract_code<- as.character(df_nycevict_raw$tract_code)
# So I'll now join both these files on tract_code
df_nycacs_evict_raw <- inner_join(df_nycacs_raw, df_nycevict_raw, by=c("tract_code"))
dim(df_nycacs_evict_raw) # [1] 3730 rows with 1010 columns
# lowercase column names
lowercase_cols<- function(df){
  for (col in colnames(df)) {
    colnames(df)[which(colnames(df)==col)] = tolower(col)
  }
  return(df)
}
# lower case all variable names
df_nycacs_evict_raw <- lowercase_cols(df_nycacs_evict_raw)

# Rename the column names for acs data file
setnames(df_nycacs_evict_raw, 
         old = c("dp03_0052e", "dp03_0062e", "dp03_0066e", "dp03_0068e",
                 "dp03_0074e", "dp03_0075e", "dp03_0076e", "dp03_0086e",
                 "dp03_0093e", "dp03_0094e", "dp04_0117e", "dp04_0136e", 
                 "dp04_0137e", "dp04_0138e", "dp04_0139e", "dp04_0140e", 
                 "dp04_0141e", "dp04_0142e"),
         
         new = c("huse_incm_less10K", "huse_incm_median","huse_with_ssn","huse_incm_retr",
                 "huse_incm_with_fdstmp","fmlys","fmly_incm_less10K","fmly_incm_median",
                 "wrkr_erng_male", "wrkr_erng_female", "huse_mrtg_no","huse_incm_by_rent",
                 "huse_incm_by_rent_less15pct","huse_incm_by_rent_less20pct",
                 "huse_incm_by_rent_less25pct","huse_incm_by_rent_less30pct",
                 "huse_incm_by_rent_less35pct","huse_incm_by_rent_more35pct"
                 )
         )

# subset the data based on identified variables from the data dictionary
subset_vars <- c("huse_incm_less10K", "huse_incm_median","huse_with_ssn","huse_incm_retr",
                 "huse_incm_with_fdstmp","fmlys","fmly_incm_less10K","fmly_incm_median",
                 "wrkr_erng_male", "wrkr_erng_female", "huse_mrtg_no","huse_incm_by_rent",
                 "huse_incm_by_rent_less15pct","huse_incm_by_rent_less20pct",
                 "huse_incm_by_rent_less25pct","huse_incm_by_rent_less30pct",
                 "huse_incm_by_rent_less35pct","huse_incm_by_rent_more35pct",
                 
                 "court_index_number", "docket_number","eviction_address","eviction_apt_num",
                 "executed_year","executed_month" ,"executed_day", "marshal_first_name",
                 "marshal_last_name","residential_commercial_ind","borough","eviction_zip",
                 "address.cleaned", "state","input_address","match_indicator" ,"match_type",
                 "matched_address","lon","lat","tiger_line_id","side", "state_code",
                 "county_code", "tract_code", "block_code"
                 )
# write to disc
write.csv(df_nycacs_evict_raw, file =  "data//_volunteer_created_datasets//df_nycacs_evict_raw.csv")

# Take a subset of nycacs_evict_raw file by using the variables identified above (see "subset_vars" variable) for further analysis
df_subset<- df_nycacs_evict_raw[,subset_vars]
dim(df_subset) # [1] 3730 rows in 44 variables
# lowercase all variables
df_subset<- lowercase_cols(df_subset)

str(df_subset) # 1:18 are continuous variables
# data summary for continuous variables
summary(df_subset[,c(1:18)]) # finding: variable wrkr_erng_male has negative value. replace it with 0
table(df_subset$wrkr_erng_male) # 45 negative values
# filter out negative values from variable wrkr_erng_male
df_subset<- df_subset %>%
  filter(wrkr_erng_male>0)

# write to disc
write.csv(df_subset, file =  "data//_volunteer_created_datasets//df_nycacs_evict_raw_subset.csv")


