# -------------------------------------------------------------------------
# Title    : Plots Mapping InMAP Results for High-Exposure Counties
# Author   : Paolo Dalla Torre
# Date     : 2025-10-28
# Purpose  :  map only the counties exceeding 1e-3 µg/m³.
# -------------------------------------------------------------------------
# 0. SETUP ------------------------------------------------------------------
timestamp <- format(Sys.Date(), "%y.%m.%d")
out_dir <- getwd()
run_dir <- file.path(out_dir,timestamp)
# Create input folder if it does not exist
dir.create(run_dir,"plots", showWarnings = FALSE)
plots_dir <- file.path(run_dir,"plots")

# Input & output paths

# 1. DATA CONFIGURATION -------------------------------------------------------
# Keep only counties with weighted PM2.5 > 1e-3
threshold <- 1e-3
# use filtered version only to define zoom area
counties_filt <- counties_out %>% filter(pm25_weighted > threshold)

plot_crs <- 3857  # Web Mercator (horizontal state line, uses meters)

# transform everything to plotting CRS
tracts_p <- tracts_out %>% filter(pm25_weighted > 1e-8) %>% st_transform(plot_crs)  # all tracts (no filter)
counties_p_all <- counties_out %>% filter(pm25_weighted >1e-8) %>% st_transform(plot_crs)
states_p <- states(cb = TRUE, year = 2024) %>%
  filter(STUSPS %in% c("VA", "NC")) %>% st_transform(plot_crs)


# 2. DRAW CENSUS TRACT MAP ----------------------------------------------------
### 2.1 compute labels from filtered region
county_labels <- st_centroid(counties_filt %>% st_transform(plot_crs)) %>%
  st_coordinates() %>% as_tibble() %>%
  bind_cols(counties_filt %>% st_drop_geometry()) %>%
  transmute(NAME, X = X, Y = Y) %>%
  left_join(
    tibble(NAME = c("Pittsylvania", "Toombs"),
           nudge_x = c(5000, 0),
           nudge_y = c(25000, 0)),
    by = "NAME"
  ) %>%
  tidyr::replace_na(list(nudge_x = 0, nudge_y = 0))

state_labels <- state_labels %>%
  mutate(
    nudge_x = ifelse(STUSPS == "VA", -180000,
                     ifelse(STUSPS == "NC", -90000, 0)),
    nudge_y = ifelse(STUSPS == "VA", -50000,
                     ifelse(STUSPS == "NC", -40000, 0))
  )

### 2.2 define plot window
bb <- st_bbox(counties_filt %>% st_transform(plot_crs))
dx   <- bb$xmax - bb$xmin; dy <- bb$ymax - bb$ymin
xlim <- c(bb$xmin - 0.15*dx, bb$xmax)
ylim <- c(bb$ymin - 0.09*dy, bb$ymax + 0.09*dy)

### 2.3 plot 
tract_plot <- ggplot() +
  geom_sf(data = tracts_p, aes(fill = pm25_weighted), color = NA) +
  geom_sf(data = counties_p_all, fill = NA, color = "gray") +
  geom_sf(data = st_transform(st_as_sf(tibble(lon = -79.348861, lat = 36.85),
                                       coords = c("lon", "lat"), crs = 4326),
                              plot_crs),
          color = "red", fill = "red", shape = 21, size = 3, stroke = 0.3) +  
  geom_text(data = county_labels, aes(x = X, y = Y, label = NAME),
            nudge_x = county_labels$nudge_x, nudge_y = county_labels$nudge_y,
            size = 4, color = "gray20", check_overlap = TRUE) +
  geom_sf(data = states_p, fill = NA, color = "black", size = 0.7, linewidth = 0.4) +
  geom_text(data = state_labels, aes(x = X, y = Y, label = STUSPS),
            nudge_x = state_labels$nudge_x, nudge_y = state_labels$nudge_y,
            fontface = "bold", size = 6) +
  scale_fill_viridis_c(
    option = "magma",
    direction = -1,
    alpha = 0.9,
    trans = scales::sqrt_trans(), #recently added
    limits = c(0, max(tracts_p$pm25_weighted, na.rm = TRUE)),
    oob = scales::squish,
    name = expression(PM[2.5]~"(µg/"*m^3*")"),
    guide = guide_colorbar(
      barwidth  = unit(8, "cm"),
      barheight = unit(0.5, "cm"),
      title.position = "top",
      title.hjust    = 0.5
    )
  ) +
  theme_minimal(base_size = 14) +
  theme(legend.position = "bottom", panel.grid = element_blank(),
        axis.text = element_blank(), axis.ticks = element_blank(),
        axis.title = element_blank()) +
  coord_sf(crs = st_crs(plot_crs), xlim = xlim, ylim = ylim, expand = FALSE)

tract_plot

### 2.4 SAVE 
ggsave("tract_map.png", tract_plot, path=plots_dir)



# 3 ZOOMED IN CENSUS TRACT PLOT-----------------------------------------------
# 3.1 Tract zoom plot looks at areas that have at least over 0.01
tract_zoom <- tracts_p %>% filter(pm25_weighted > 1e-3)
# 3.2 transform everything to plotting CRS
tracts_p   <- tracts_out   %>% filter(pm25_weighted > 1e-4) %>% st_transform(plot_crs)
counties_p <- counties_out %>% filter(pm25_weighted > 1e-2) %>% st_transform(plot_crs)
states_p   <- states(cb = TRUE, year = 2024) %>%
  filter(STUSPS %in% c("VA", "NC")) %>% st_transform(plot_crs)

# 3.3 recompute label centroids and nudges (in same CRS)
county_labels <- st_centroid(counties_p) %>%
  st_coordinates() %>% as_tibble() %>%
  bind_cols(counties_p %>% st_drop_geometry()) %>%
  transmute(NAME, X = X, Y = Y) %>%
  left_join(
    tibble(NAME = c("Pittsylvania", "Toombs"),
           nudge_x = c(3000, 0),
           nudge_y = c(24000, 0)),
    by = "NAME"
  ) %>%
  tidyr::replace_na(list(nudge_x = 0, nudge_y = 0))

state_labels <- state_labels %>%
  mutate(
    nudge_x = ifelse(STUSPS == "VA",  60000, 0),
    nudge_y = ifelse(STUSPS == "VA", -60000, ifelse(STUSPS == "NC", 30000, 0))
  )

bb <- st_bbox(counties_p)
dx <- bb$xmax - bb$xmin; dy <- bb$ymax - bb$ymin
xlim <- c(bb$xmin - 0.05*dx, bb$xmax + 0.05*dx)
ylim <- c(bb$ymin - 0.05*dy, bb$ymax + 0.05*dy)

###3.4 plot zoomed-in census tract

tract_plot_zoom <- ggplot() +
  geom_sf(data = tracts_p, aes(fill = pm25_weighted), color = NA) +
  geom_sf(data = counties_p_all, fill = NA, color = "gray") +
  geom_sf(data = st_transform(st_as_sf(tibble(lon = -79.348861, lat = 36.85),
                                       coords = c("lon", "lat"), crs = 4326),
                              plot_crs),
          color = "red", fill = "red", shape = 21, size = 3, stroke = 0.3) +  
  geom_text(data = county_labels, aes(x = X, y = Y, label = NAME),
            nudge_x = county_labels$nudge_x, nudge_y = county_labels$nudge_y,
            size = 5, color = "gray20") +
  geom_sf(data = states_p, fill = NA, color = "black", size = 0.7) +
  geom_text(data = state_labels, aes(x = X, y = Y, label = STUSPS),
            nudge_x = state_labels$nudge_x, nudge_y = state_labels$nudge_y,
            fontface = "bold", size = 7) +
  scale_fill_viridis_c(
    option = "magma",
    direction = -1,   # flips the scale so darker = higher PM2.5
    alpha = 0.9,
    trans = scales::sqrt_trans(), #recently added
    limits = c(min(tracts_p$pm25_weighted, na.rm = TRUE), max(tracts_p$pm25_weighted, na.rm = TRUE)),
    oob = scales::squish,
    name = expression(PM[2.5]~"(µg/"*m^3*")"),
    guide = guide_colorbar(
      barwidth  = unit(8, "cm"),
      barheight = unit(0.5, "cm"),
      title.position = "top",
      title.hjust    = 0.5
    )
  ) +
  theme_minimal(base_size = 14) +
  theme(legend.position = "bottom", panel.grid = element_blank(),
        axis.text = element_blank(), axis.ticks = element_blank(),
        axis.title = element_blank()) +
  coord_sf(crs = st_crs(plot_crs), xlim = xlim, ylim = ylim, expand = FALSE)

tract_plot_zoom


#3.5 Save plot
ggsave("tract_map_zoom.png", tract_plot_zoom, path=plots_dir)


# 3 COUNTY PLOT----------------------------------------------------------------

### 3.1recompute label centroids and nudges (in same CRS)
county_labels <- st_centroid(counties_p) %>%
  st_coordinates() %>% as_tibble() %>%
  bind_cols(counties_p %>% st_drop_geometry()) %>%
  transmute(NAME, X = X, Y = Y) %>%
  left_join(
    tibble(NAME = c("Pittsylvania", "Toombs"),
           nudge_x = c(0, 0),
           nudge_y = c(0, 0)),
    by = "NAME"
  ) %>%
  tidyr::replace_na(list(nudge_x = 0, nudge_y = 0))

pitt <- dplyr::filter(county_labels, NAME == "Pittsylvania")


#### 3.2 set the plot limits
xlim <- c(bb$xmin - 0.2*dx , bb$xmax + 0.2*dx )
ylim <- c(bb$ymin - 0.1*dy, bb$ymax +0.1*dy )


### 3.3 Create county map
county_map <- ggplot() +
  # High‐exposure tracts
  geom_sf(data = counties_p_all,
          aes(fill = pm25_weighted),
          color = NA) +
  # County outlines
  geom_sf(data = counties_filt, fill = NA, color = "gray50") +
  # Power plant point
  geom_sf(data = st_transform(st_as_sf(tibble(lon = -79.348861, lat = 36.85),
                                       coords = c("lon", "lat"), crs = 4326),
                              plot_crs),
          color = "red", fill = "red", shape = 21, size = 3, stroke = 0.3) +
  # County labels
  geom_text(data = county_labels, aes(X, Y, label = NAME),
            nudge_x = county_labels$nudge_x, nudge_y = county_labels$nudge_y,
            size = 4, color = "gray20") +
  geom_text(data = pitt, aes(X, Y, label = NAME),
            nudge_x = pitt$nudge_x, nudge_y = pitt$nudge_y,
            size = 4, color = "white") +
  # State outlines
  geom_sf(data = states_p, fill = NA, color = "black", size = 1) +
  # State labels
  geom_text(
    data    = state_labels,
    aes(x = X, y = Y, label = STUSPS),
    nudge_x = state_labels$nudge_x,
    nudge_y = state_labels$nudge_y,
    fontface = "bold", size = 6
  ) +
  # make the fill scale longer
  scale_fill_viridis_c(
    option = "magma",
    direction = -1,
    alpha = 0.9,
    limits = c(0, max(counties_p_all$pm25_weighted, na.rm = TRUE)),
    oob = scales::squish,
    name = expression(PM[2.5]~"(µg/"*m^3*")"),
    labels = function(x) sub("\\.?0+$", "", format(x, scientific = FALSE)),
    guide = guide_colorbar(
      barwidth  = unit(8, "cm"),
      barheight = unit(0.5, "cm"),
      title.position = "top",
      title.hjust = 0.5
    )
  ) +
  theme(
    legend.position    = "bottom",
    legend.direction   = "horizontal",
    legend.key.width   = unit(8, "cm"),   # ensure key matches
    legend.key.height  = unit(0.5, "cm")
  ) + 
  coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    panel.grid      = element_blank(),
    axis.text       = element_blank(),
    axis.ticks      = element_blank(),
    axis.title      = element_blank()
  )

county_map

### 3.4 save county map
ggsave("county_map.png", county_map, path=plots_dir)
