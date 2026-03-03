# ------------------------------------------------------------------------------
# 5. sociodemographic_analysis.R
#
# Purpose:
#   Create reproducible sociodemographic summary table for populations exposed to
#   additional plant-attributable PM2.5 (e.g., totalPM25 > threshold).
#
# Inputs (defaults are repo-friendly relative paths):
#   - tracts_with_pm25.csv : output from 3.post-processing.R (must include GEOID and totalPM25)
#   - 2022_tract_acs5.csv.gz (or similar) : tract-level ACS indicators (must include GEOID and population + pct vars)
#
# Outputs:
#   - table2_sociodemographics.csv
#   - table2_sociodemographics.md  (simple GitHub-friendly markdown table)
#
# Run:
#   Rscript 5.sociodemographic_analysis.R \
#     --pm25_csv data/tracts_with_pm25.csv \
#     --acs_csv  data/2022_tract_acs5.csv.gz \
#     --threshold 0.1 \
#     --out_dir results
# ------------------------------------------------------------------------------

# ---- packages ----------------------------------------------------------------
pkgs <- c("data.table", "dplyr", "readr", "tidyr", "knitr")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       "\nInstall with: install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))")
}
library(data.table)
library(dplyr)
library(readr)

# ---- CLI args ----------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (!is.na(i) && i < length(args)) return(args[i + 1])
  default
}

pm25_csv   <- get_arg("--pm25_csv", "tracts_with_pm25.csv")
acs_csv    <- get_arg("--acs_csv",  "2022_tract_acs5.csv.gz")
threshold  <- as.numeric(get_arg("--threshold", "0.1"))
out_dir    <- get_arg("--out_dir",  "results")

timestamp <- format(Sys.Date(), "%y.%m.%d")
run_path <- file.path(getwd(),timestamp)
dir.create(file.path(run_path, "results"), recursive = TRUE)

results_dir <- file.path(run_path, "results" )

# ---- helpers -----------------------------------------------------------------
# Robust GEOID handling: keep as character with leading zeros.
as_geoid_chr <- function(x) sprintf("%011s", as.character(x))

# Convert first 2 digits of GEOID (state FIPS) to state abbreviation
state_abbr_from_geoid <- function(geoid_chr) {
  fips <- substr(geoid_chr, 1, 2)
  # Minimal mapping (expand if needed)
  map <- c(
    "01"="AL","02"="AK","04"="AZ","05"="AR","06"="CA","08"="CO","09"="CT","10"="DE","11"="DC",
    "12"="FL","13"="GA","15"="HI","16"="ID","17"="IL","18"="IN","19"="IA","20"="KS","21"="KY",
    "22"="LA","23"="ME","24"="MD","25"="MA","26"="MI","27"="MN","28"="MS","29"="MO","30"="MT",
    "31"="NE","32"="NV","33"="NH","34"="NJ","35"="NM","36"="NY","37"="NC","38"="ND","39"="OH",
    "40"="OK","41"="OR","42"="PA","44"="RI","45"="SC","46"="SD","47"="TN","48"="TX","49"="UT",
    "50"="VT","51"="VA","53"="WA","54"="WV","55"="WI","56"="WY"
  )
  unname(map[fips])
}

wmean <- function(x, w) {
  stats::weighted.mean(x, w = w, na.rm = TRUE)
}

fmt_pct <- function(x) sprintf("%.2f", 100 * x)          # assumes 0-1 fractions
fmt_num <- function(x) formatC(x, format = "f", digits = 2)
fmt_usd0 <- function(x) paste0("$", formatC(round(x, 0), format = "d", big.mark = ","))

# ---- load data ----------------------------------------------------------------
pm25_csv <- file.path(timestamp, "post-processing", "tracts_with_pm25.csv")
pm25 <- readr::read_csv(pm25_csv, show_col_types = FALSE) %>%
  mutate(GEOID = as_geoid_chr(GEOID))

acs_csv <- file.path("data", "2022_tract_acs5.csv.gz")
acs <- data.table::fread(acs_csv) %>%
  tibble::as_tibble() %>%
  mutate(GEOID = as_geoid_chr(GEOID))


# ---- derive variables ---------------------------------------------------------
# If pct_age_above_65 not present, try to construct from typical ACS columns used in your earlier script.
if (!"pct_age_above_65" %in% names(acs)) {
  age_cols <- c("pct_age_65_to_66","pct_age_67_to_69","pct_age_70_to_74",
                "pct_age_75_to_79","pct_age_80_to_84","pct_age_over_85")
  if (all(age_cols %in% names(acs))) {
    acs <- acs %>% mutate(pct_age_above_65 = rowSums(across(all_of(age_cols)), na.rm = TRUE))
  } else {
    warning("pct_age_above_65 not found and age component columns missing; Age 65+ will be NA.")
    acs$pct_age_above_65 <- NA_real_
  }
}

# Keep only columns needed
keep <- c("GEOID","population","pct_white","pct_black","pct_hispanic","pct_asian",
          "pct_age_above_65","pct_poverty","med_household_income","med_property_value")
missing_keep <- setdiff(keep, names(acs))
if (length(missing_keep)) {
  stop("ACS file missing required columns: ", paste(missing_keep, collapse = ", "))
}

acs2 <- acs %>%
  select(all_of(keep)) %>%
  mutate(
    STUSPS = state_abbr_from_geoid(GEOID)
  )


dat <- pm25 %>%
  left_join(acs2, by = "GEOID")

dat <- dat %>% mutate(STUSPS = state_abbr_from_geoid(GEOID))

if (!"pm25_weighted" %in% names(dat)) {
  stop("pm25_csv must contain a 'pm25_weighted' column (plant-attributable PM2.5 by tract).")
}

# ---- define groups ------------------------------------------------------------
exposed <- dat %>% filter(pm25_weighted > threshold)
va_avg  <- dat %>% filter(STUSPS == "VA")
us_avg  <- dat

if (nrow(exposed) == 0) {
  warning("No tracts exceed threshold = ", threshold, ". Exposed column will be NA.")
}

# ---- compute summary stats ----------------------------------------------------
summarize_group <- function(df) {
  tibble(
    `White (%)`                 = wmean(df$pct_white, df$population),
    `Black (%)`                 = wmean(df$pct_black, df$population),
    `Hispanic (%)`              = wmean(df$pct_hispanic, df$population),
    `Asian (%)`                 = wmean(df$pct_asian, df$population),
    `Age 65+ (%)`               = wmean(df$pct_age_above_65, df$population),
    `Poverty rate (%)`          = wmean(df$pct_poverty, df$population),
    `Median household income`   = wmean(df$med_household_income, df$population),
    `Median property value`     = wmean(df$med_property_value, df$population)
  )
}

tab_exposed <- summarize_group(exposed)
tab_va      <- summarize_group(va_avg)
tab_us      <- summarize_group(us_avg)

tab <- bind_rows(
  tab_exposed,
  tab_va,
  tab_us
) %>%
  mutate(group = c(paste0(">", threshold, " μg/m³"), "VA Average", "US Average")) %>%
  relocate(group)

# ---- format for publication / GitHub -----------------------------------------
# Convert to long -> pretty wide table with formatted values
tab_fmt <- tab %>%
  mutate(
    across(c(`White (%)`,`Black (%)`,`Hispanic (%)`,`Asian (%)`,`Age 65+ (%)`,`Poverty rate (%)`), fmt_pct),
    `Median household income` = fmt_usd0(`Median household income`),
    `Median property value`   = fmt_usd0(`Median property value`)
  )

tab_out_csv <- file.path(results_dir, "table2_sociodemographics.csv")
write_csv(tab_fmt, tab_out_csv)

# GitHub-friendly markdown table
tab_md <- tab_fmt %>%
  pivot_longer(-group, names_to = "Indicator", values_to = "Value") %>%
  tidyr::pivot_wider(names_from = group, values_from = Value)

tab_out_md <- file.path(results_dir, "table2_sociodemographics.md")
md_lines <- c(
  "## Table 2. Demographic and socioeconomic indicators for populations exposed to additional plant-attributable PM\u2082.\u2085",
  "",
  paste0("Threshold: **", threshold, " μg/m³**  \nValues reflect population-weighted tract averages."),
  "",
  knitr::kable(tab_md, format = "pipe")
)
writeLines(md_lines, tab_out_md)

message("✅ Wrote: ", tab_out_csv)
message("✅ Wrote: ", tab_out_md)
