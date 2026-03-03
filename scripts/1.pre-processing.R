# =============================================================================
# Plant Emissions Shapefile Generator for InMAP
# Computes annual emissions from a coal plant and exports a shapefile input
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Install and Load Libraries and check working directory
# -----------------------------------------------------------------------------
packages <- c("readr", "sf", "dplyr", "ggplot2", "units", 
              "rnaturalearth", "rnaturalearthdata", "tigris")

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

#directory check
getwd()

# -----------------------------------------------------------------------------
# 2. Define Plant Characteristics
# Includes location, capacity, and emission factors (kg/MWh)
# -----------------------------------------------------------------------------
plant <- tibble::tibble(
  lat                    = 36.85,
  long                   = -79.348861,
  power_capacity_mw      = 3500,
  max_power_generation_mwh = 30660000,
  `PM25_factor(kg/MWh)` = 0.0128936,
  `CO2_factor(kg/MWh)`  = 375,
  `NOx_factor(kg/MWh)`  = 0.0149,
  `SO2_factor(kg/MWh)`  = 0.0018
)

# Convert to spatial object (WGS84)
plant_sf <- st_as_sf(plant, coords = c("long", "lat"), crs = "WGS84")

# -----------------------------------------------------------------------------
# 3. Plot Plant Location
# -----------------------------------------------------------------------------

# World map
world <- ne_countries(scale = "medium", returnclass = "sf")
ggplot() +
  geom_sf(data = world, fill = "lightblue") +
  geom_sf(data = plant_sf, color = "red", size = 3) +
  ggtitle("Plant Location - World")

# Continental US map with state borders
usa <- ne_countries(country = "united states of america", scale = "medium", returnclass = "sf") %>%
  st_crop(xmin = -125, xmax = -66, ymin = 24, ymax = 50)

states <- states(cb = TRUE, resolution = "20m") %>%
  filter(!STUSPS %in% c("AK", "HI", "PR", "GU", "VI", "MP", "AS")) %>%
  st_transform(4326)

ggplot() +
  geom_sf(data = usa, fill = "lightblue") +
  geom_sf(data = states, fill = NA, color = "black", linewidth = 0.3) +
  geom_sf(data = plant_sf, color = "red", size = 3) +
  ggtitle("Plant Location - Continental US")

# -----------------------------------------------------------------------------
# 4. Calculate Annual Emissions
# Assumes a capacity factor (uptime) applied to max generation
# -----------------------------------------------------------------------------
uptime <- 0.75  # 75% capacity factor

plant_sf <- plant_sf %>%
  mutate(
    pm25_emissions_uptime = max_power_generation_mwh * uptime * `PM25_factor(kg/MWh)`,
    co2_emissions_uptime  = max_power_generation_mwh * uptime * `CO2_factor(kg/MWh)`,
    nox_emissions_uptime  = max_power_generation_mwh * uptime * `NOx_factor(kg/MWh)`,
    so2_emissions_uptime  = max_power_generation_mwh * uptime * `SO2_factor(kg/MWh)`,
    height                = 54.864  # stack height in meters (180 ft)
  )

# -----------------------------------------------------------------------------
# 5. Prepare InMAP Input
# Select and rename columns to match InMAP naming conventions
# -----------------------------------------------------------------------------
plant_sf_inmap <- plant_sf %>%
  select(pm25_emissions_uptime, nox_emissions_uptime, so2_emissions_uptime,
         height, geometry) %>%
  rename(
    PM2_5 = pm25_emissions_uptime,
    NOx   = nox_emissions_uptime,
    SOx   = so2_emissions_uptime
  )

# -----------------------------------------------------------------------------
# 6. Export Shapefile
# Writes InMAP input shapefile into /input folder
# -----------------------------------------------------------------------------

timestamp <- format(Sys.Date(), "%y.%m.%d")

#create the folder where the inmap run will be stored
dir.create(timestamp, showWarnings = FALSE)
run_path <- file.path(getwd(),timestamp)

# Create input folder
dir.create(run_path,"input")
input_path <- file.path(run_path,"input")

# Reproject to USA Contiguous Albers Equal Area (ESRI:102003)
plant_sf_inmap <- st_transform(plant_sf_inmap, crs = "ESRI:102003")

# Input path
input_file_path <- file.path(input_path,
  sprintf("input_%s.shp", timestamp)
)

# Write shapefile
st_write(
  plant_sf_inmap[1, c("geometry", "PM2_5", "NOx", "SOx")],
  dsn = input_file_path,
  delete_layer = TRUE
)
