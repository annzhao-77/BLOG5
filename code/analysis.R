library(dplyr)
library(ggplot2)
library(sf)

# Download data
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
options(timeout = 180)
population_url <- "https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/counties/totals/co-est2025-alldata.csv"
boundary_url <- "https://www2.census.gov/geo/tiger/GENZ2023/shp/cb_2023_us_county_5m.zip"
population_file <- "data/raw/co-est2025-alldata.csv"
boundary_file <- "data/raw/cb_2023_us_county_5m.zip"
if (!file.exists(population_file)) download.file(population_url, population_file, mode = "wb")
if (!file.exists(boundary_file)) download.file(boundary_url, boundary_file, mode = "wb")

# Keep PA counties
raw <- read.csv(population_file, encoding = "latin1")
pa <- raw %>% filter(STATE == 42, SUMLEV == 50)
stopifnot(nrow(pa) == 67, !anyDuplicated(pa$COUNTY))

# The 2020 fields cover April-June; sum through 2025 for the full period.
years <- 2020:2025
pa$births <- rowSums(pa[paste0("BIRTHS", years)])
pa$deaths <- rowSums(pa[paste0("DEATHS", years)])
pa$domestic <- rowSums(pa[paste0("DOMESTICMIG", years)])
pa$international <- rowSums(pa[paste0("INTERNATIONALMIG", years)])
pa$residual <- rowSums(pa[paste0("RESIDUAL", years)])
counties <- pa %>% transmute(
  GEOID = sprintf("%02d%03d", STATE, COUNTY),
  county = sub(" County$", "", CTYNAME),
  population_2020 = ESTIMATESBASE2020, population_2025 = POPESTIMATE2025,
  change = population_2025 - population_2020,
  births, deaths, natural = births - deaths, domestic, international,
  migration = domestic + international, residual,
  growth_pct = 100 * change / population_2020,
  natural_pct = 100 * natural / population_2020,
  domestic_pct = 100 * domestic / population_2020,
  international_pct = 100 * international / population_2020,
  migration_pct = 100 * migration / population_2020,
  residual_pct = 100 * residual / population_2020
)
# Check missing values and component totals
stopifnot(!anyNA(counties), all(counties$population_2020 > 0))
stopifnot(all(counties$change == counties$natural + counties$migration + counties$residual))
stopifnot(all(counties$migration == rowSums(pa[paste0("NETMIG", years)])))
stopifnot(all(counties$natural == rowSums(pa[paste0("NATURALCHG", years)])))
write.csv(counties, "results/tables/county_summary.csv", row.names = FALSE)

state <- counties %>% summarise(
  population_2020 = sum(population_2020), population_2025 = sum(population_2025),
  change = sum(change), natural = sum(natural), domestic = sum(domestic),
  international = sum(international), migration = sum(migration), residual = sum(residual),
  growing_counties = sum(counties$change > 0), declining_counties = sum(counties$change < 0),
  natural_decrease_counties = sum(counties$natural < 0),
  net_inflow_counties = sum(counties$migration > 0),
  growing_despite_natural_decrease = sum(counties$change > 0 & counties$natural < 0),
  declining_despite_net_inflow = sum(counties$change < 0 & counties$migration > 0)
) %>% mutate(growth_pct = 100 * change / population_2020)
official_state <- raw %>% filter(STATE == 42, SUMLEV == 40)
stopifnot(sum(counties$population_2025) == official_state$POPESTIMATE2025)
stopifnot(sum(counties$population_2020) == official_state$ESTIMATESBASE2020)
write.csv(state, "results/tables/state_summary.csv", row.names = FALSE)
print(state)

# Join county boundaries
shape_folder <- tempfile("county_shapes_")
dir.create(shape_folder)
unzip(boundary_file, exdir = shape_folder)
boundaries <- st_read(file.path(shape_folder, "cb_2023_us_county_5m.shp"), quiet = TRUE) %>%
  filter(STATEFP == "42") %>% select(GEOID, geometry) %>% st_transform(5070)
stopifnot(nrow(boundaries) == 67, !anyDuplicated(boundaries$GEOID),
          setequal(boundaries$GEOID, counties$GEOID), all(st_is_valid(boundaries)))
map_data <- left_join(boundaries, counties, by = "GEOID")
stopifnot(!anyNA(map_data$growth_pct), !anyNA(map_data$migration_pct))

# Counties used for comparison
examples <- c("Pike", "Cumberland", "Butler", "Westmoreland", "Philadelphia", "Cameron")
labels <- map_data %>% filter(county %in% examples)
labels <- suppressWarnings(st_point_on_surface(labels))
period <- "April 1, 2020 to July 1, 2025 | 67 Pennsylvania counties"
source_note <- "Source: U.S. Census Bureau, Vintage 2025; 2023 cartographic county boundaries.\nCumulative change per 100 residents in the April 2020 estimates base; not an annual rate."
map_theme <- theme_void(base_size = 13) + theme(
  plot.title = element_text(face = "bold", size = 20, color = "#193E4C"),
  plot.subtitle = element_text(color = "#52636D", margin = margin(b = 12)),
  plot.caption = element_text(hjust = 0, size = 10, color = "#52636D"),
  legend.position = "bottom", legend.title = element_text(size = 11),
  plot.margin = margin(15, 20, 15, 20), plot.background = element_rect(fill = "white", color = NA)
)
# Use the same color scale for both maps
limit <- ceiling(max(abs(c(counties$growth_pct, counties$migration_pct))))
map1 <- ggplot(map_data) +
  geom_sf(aes(fill = growth_pct), color = "white", linewidth = 0.25) +
  geom_sf_label(data = labels, aes(label = county), size = 3.1,
                fill = "white", color = "#26343D", linewidth = 0.15) +
  scale_fill_gradient2(low = "#BA552A", mid = "#F7F7F2", high = "#176385",
                       midpoint = 0, limits = c(-limit, limit), name = "Population change (%)") +
  labs(title = "Where is Pennsylvania growing?", subtitle = period, caption = source_note) +
  map_theme
map2 <- ggplot(map_data) +
  geom_sf(aes(fill = migration_pct), color = "white", linewidth = 0.25) +
  geom_sf_label(data = labels, aes(label = county), size = 3.1,
                fill = "white", color = "#26343D", linewidth = 0.15) +
  scale_fill_gradient2(low = "#BA552A", mid = "#F7F7F2", high = "#176385",
                       midpoint = 0, limits = c(-limit, limit), name = "Net migration / starting population (%)") +
  labs(title = "Where does migration add population?", subtitle = period, caption = source_note) +
  map_theme

# Compare population-change components
selected <- counties %>% filter(county %in% examples)
components <- bind_rows(
  selected %>% transmute(county, component = "Natural change", value = natural_pct),
  selected %>% transmute(county, component = "Domestic migration", value = domestic_pct),
  selected %>% transmute(county, component = "International migration", value = international_pct),
  selected %>% transmute(county, component = "Residual", value = residual_pct)
)
components$county <- factor(components$county, levels = rev(examples))
selected$county <- factor(selected$county, levels = rev(examples))
write.csv(components, "results/tables/selected_components.csv", row.names = FALSE)
plot3 <- ggplot(components, aes(x = value, y = county, fill = component)) +
  geom_vline(xintercept = 0, color = "#59666E", linewidth = 0.4) +
  geom_col(width = 0.58, position = "stack") +
  geom_point(data = selected, aes(x = growth_pct, y = county, shape = "Total change"),
             inherit.aes = FALSE, size = 3.5, color = "#17272D") +
  scale_shape_manual(values = c("Total change" = 18), name = NULL) +
  scale_fill_manual(values = c("Natural change" = "#C46C37", "Domestic migration" = "#326D99",
                              "International migration" = "#479C91", "Residual" = "#A5A5A5"), name = NULL) +
  labs(title = "Why arrivals do not always mean growth",
       subtitle = "Six contrasting counties | April 2020 to July 2025",
       x = "Contribution to population change (percentage points)", y = NULL,
       caption = "Source: U.S. Census Bureau, Vintage 2025. Each component is divided by the county's April 2020 base.\nPositive and negative components stack separately; the diamond is their net sum. Residuals are retained.") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 20, color = "#193E4C"),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "bottom", legend.box = "vertical",
        plot.caption = element_text(hjust = 0, size = 10), plot.margin = margin(15, 20, 15, 20)) +
  guides(fill = guide_legend(nrow = 2, order = 1), shape = guide_legend(order = 2))
ggsave("results/figures/population_change.png", map1, width = 11, height = 7, dpi = 200, bg = "white")
ggsave("results/figures/net_migration.png", map2, width = 11, height = 7, dpi = 200, bg = "white")
ggsave("results/figures/change_components.png", plot3, width = 11, height = 7, dpi = 200, bg = "white")
if (interactive()) { print(map1); print(map2); print(plot3) }
print(selected %>% select(county, growth_pct, natural_pct, domestic_pct, international_pct, residual_pct))
