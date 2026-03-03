# -------------------------------------------------------------------------
# Title    : Post-process InMAP Results
# Author   : Paolo Dalla Torre
# Date     : 2025-10-28
# Purpose  : Aggregate grid to tracts/counties, compute area-weighted 
#            PM₂.₅, and map only the counties exceeding 1e-3 µg/m³.
# -------------------------------------------------------------------------
# 0. SETUP ------------------------------------------------------------------
library(sf)
library(dplyr)
library(readr)
library(ggplot2)
library(tigris)
library(tidyr)
library(ggrepel)
library(cowplot)
options(tigris_use_cache = TRUE)

# 1. CONFIGURATION ----------------------------------------------------------
timestamp <- format(Sys.Date(), "%y.%m.%d")
out_dir <- getwd()
run_dir <- file.path(out_dir,timestamp)
# Create input folder if it does not exist
dir.create(timestamp,"post-processing")
post_dir <- file.path(run_dir,"post-processing")

# Set paths for analysis
inmap_shp <- file.path(run_dir, sprintf("output/output_%s.shp",timestamp))
tracts_csv  <- file.path(post_dir, "tracts_with_pm25.csv")
counties_csv<- file.path(post_dir, "counties_with_pm25.csv")

# 2. LOAD SPATIAL DATA ------------------------------------------------------
grid       <- st_read(inmap_shp, quiet = TRUE) 
tracts_sf  <- tracts(cb = TRUE, year = 2024) %>% st_transform(st_crs(grid))
counties_sf<- counties(cb = TRUE, year = 2024)%>% st_transform(st_crs(grid))

message("✔ Loaded grid (", nrow(grid), " cells), tracts and counties.")

# 3. PREPARE GRID FOR AGGREGATION -------------------------------------------
cells <- grid %>%
  mutate(
    cell_id   = row_number(),
    cell_area = as.numeric(st_area(.))
  ) %>%
  select(cell_id, TotalPM25, TotalPop, cell_area, geometry)

# 4. AREA-WEIGHTED AGGREGATION FUNCTION -------------------------------------

aggregate_aw <- function(polys_sf, id_col) {
  # 1) Intersect polygons with grid cells
  overlap <- st_intersection(
    polys_sf %>% select(!!sym(id_col)),
    cells
  )
  
  # 2) Compute overlap areas
  overlap <- overlap %>%
    mutate(
      overlap_area = as.numeric(st_area(.)),                 # m² of polygon ∩ cell
      pm_area       = TotalPM25 * overlap_area               # PM₂.₅·pop in that overlap
    )
  
  # 3) Summarize to per-polygon totals & compute weighted mean
  summary_tbl <- overlap %>%
    st_drop_geometry() %>%
    group_by(!!sym(id_col)) %>%
    summarize(
      #total_pop     = sum(pop_alloc, na.rm = TRUE),
      tot_area = sum(overlap_area, na.rm = TRUE),
      total_pm_area  = sum(pm_area,   na.rm = TRUE),
      pm25_weighted = total_pm_area / tot_area              # µg/m³, area-weighted
    )
  
  # 4) Join back to the original polygons
  result <- polys_sf %>%
    left_join(summary_tbl, by = id_col)
  
  return(result)
}


aggregate_aw <- function(polys_sf, id_col) {
  
  overlap <- st_intersection(
    polys_sf %>% dplyr::select(!!rlang::sym(id_col)),
    cells
  )
  
  overlap <- overlap %>%
    dplyr::mutate(
      overlap_area = as.numeric(st_area(.)),        # m² of polygon ∩ cell
      pm_area      = TotalPM25 * overlap_area       # (µg/m³) * m²
    )
  
  summary_tbl <- overlap %>%
    st_drop_geometry() %>%
    dplyr::group_by(!!rlang::sym(id_col)) %>%
    dplyr::summarize(
      tot_area      = sum(overlap_area, na.rm = TRUE),
      totalPM25     = sum(pm_area,      na.rm = TRUE),  # area-integrated PM
      pm25_weighted = totalPM25 / tot_area,             # area-weighted mean (µg/m³)
      .groups = "drop"
    )
  
  polys_sf %>%
    dplyr::left_join(summary_tbl, by = id_col)
}


tracts_out   <- aggregate_aw(tracts_sf,  "GEOID")
counties_out <- aggregate_aw(counties_sf, "GEOID")


# Save CSVs
write_csv(tracts_out %>% st_drop_geometry(), tracts_csv)
write_csv(counties_out %>% st_drop_geometry(), counties_csv)
message("✔ Wrote CSVs to ", post_dir)

