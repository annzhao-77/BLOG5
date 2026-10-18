# Run after analysis.R, from the BLOG5 project root.
# install.packages(c("leaflet", "htmlwidgets"))
library(dplyr)
library(sf)
library(leaflet)
library(htmlwidgets)

counties <- read.csv("results/tables/county_summary.csv",
                     colClasses = c(GEOID = "character"))
folder <- tempfile("county_shapes_")
dir.create(folder)
unzip("data/raw/cb_2023_us_county_5m.zip", exdir = folder)
boundaries <- st_read(file.path(folder, "cb_2023_us_county_5m.shp"), quiet = TRUE) %>%
  filter(STATEFP == "42") %>% select(GEOID, geometry) %>% st_transform(4326)
map_data <- left_join(boundaries, counties, by = "GEOID")
stopifnot(nrow(map_data) == 67, !anyNA(map_data$growth_pct), !anyNA(map_data$migration_pct))

# The full values are available on hover; click keeps the same panel open.
info <- sprintf(
  paste0("<strong>%s County</strong><br>April 2020 base: %s<br>July 2025 population: %s",
         "<br>Population change: %s (%+.2f%%)",
         "<br>Net migration: %s (%+.2f%% of base)",
         "<br>Natural change: %s<br>Domestic net migration: %s",
         "<br>International net migration: %s<br>Residual: %s"),
  map_data$county,
  format(map_data$population_2020, big.mark = ",", trim = TRUE),
  format(map_data$population_2025, big.mark = ",", trim = TRUE),
  format(map_data$change, big.mark = ",", trim = TRUE), map_data$growth_pct,
  format(map_data$migration, big.mark = ",", trim = TRUE), map_data$migration_pct,
  format(map_data$natural, big.mark = ",", trim = TRUE),
  format(map_data$domestic, big.mark = ",", trim = TRUE),
  format(map_data$international, big.mark = ",", trim = TRUE),
  format(map_data$residual, big.mark = ",", trim = TRUE)
)
hover_labels <- lapply(info, htmltools::HTML)
limit <- ceiling(max(abs(c(map_data$growth_pct, map_data$migration_pct))))
palette <- colorNumeric(c("#BA552A", "#F7F7F2", "#176385"), domain = c(-limit, limit))
bounds <- st_bbox(map_data)

# A short loop draws the same interface for the two different measures.
measures <- c("growth_pct", "migration_pct")
titles <- c("Population change (%)", "Net migration / starting population (%)")
files <- c("population_change.html", "net_migration.html")
for (i in 1:2) {
  values <- map_data[[measures[i]]]
  map <- leaflet(map_data, options = leafletOptions(
    minZoom = 5, maxZoom = 12, scrollWheelZoom = FALSE)) %>%
    addPolygons(fillColor = palette(values), fillOpacity = 1,
      color = "#ffffff", weight = 1, layerId = ~GEOID,
      label = hover_labels, popup = info,
      labelOptions = labelOptions(textsize = "12px", direction = "auto"),
      highlightOptions = highlightOptions(weight = 3, color = "#26343D", bringToFront = TRUE)) %>%
    fitBounds(bounds[["xmin"]], bounds[["ymin"]], bounds[["xmax"]], bounds[["ymax"]]) %>%
    addLegend(pal = palette, values = c(-limit, limit), title = titles[i],
              position = "bottomright", opacity = 1) %>%
    addControl("<b>Pennsylvania</b><br>Apr 2020–Jul 2025<br>Hover or tap a county.<br>Drag to pan; use + / − to zoom.",
               position = "topright") %>%
    addControl("Source: U.S. Census Bureau, Vintage 2025.<br>Cumulative percentages, not annual rates.",
               position = "bottomleft")
  # No external map tiles: polygons, data, and JS/CSS are embedded in the HTML.
  # RStudio supplies Pandoc; outside RStudio, make Pandoc available first.
  html_file <- file.path(tempdir(), files[i])
  saveWidget(map, html_file, selfcontained = TRUE,
             title = titles[i], background = "#f4f6f7")
  file.copy(html_file, file.path("results/figures", files[i]), overwrite = TRUE)
}
