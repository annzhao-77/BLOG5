# Blog 5: Where Is Pennsylvania Growing?

**Question:** Which Pennsylvania counties gained population between April 1, 2020 and July 1, 2025, and what role did migration play?

[Blog source](https://github.com/annzhao-77/website/blob/main/blog/posts/post5/index.qmd) | [R script](code/analysis.R) | [County results](results/tables/county_summary.csv) | [Figures](results/figures/)

## Files

```text
BLOG5/
├── BLOG5.Rproj
├── README.md
├── code/
│   ├── analysis.R
│   └── interactive_maps.R
├── data/raw/
│   ├── co-est2025-alldata.csv
│   └── cb_2023_us_county_5m.zip
└── results/
    ├── tables/
    │   ├── county_summary.csv
    │   ├── state_summary.csv
    │   └── selected_components.csv
    └── figures/
        ├── population_change.png
        ├── net_migration.png
        ├── change_components.png
        ├── population_change.html
        └── net_migration.html
```

The raw CSV and boundary ZIP are original Census downloads, retrieved October 17, 2026. The script filters data in memory; no separate clean-data copy is needed. `county_summary.csv` contains all 67 county observations, cumulative counts, and the rates underlying the figures. `state_summary.csv` contains state totals and county counts; `selected_components.csv` contains the third figure's values. The QMD and display images are maintained in the website repository, not here.

## Reproducibility

The analysis uses R 4.5.3 and the packages `dplyr`, `ggplot2`, `sf`, `leaflet`, and `htmlwidgets`. Paths are relative to the repository root. The two scripts reproduce the results in this order:

```r
source("code/analysis.R")
source("code/interactive_maps.R")
```

Tested with R 4.5.3 on Windows. `sf` reads GIS polygons; `dplyr` handles tables; `ggplot2` draws maps and bars. The script creates output folders and regenerates three tables and three PNGs. It uses the saved input files when present, so reproduction does not require internet access after package installation. If either input is absent, it downloads that file from the official URL defined near the top of the script. It does not refresh existing snapshots automatically. The boundary ZIP is extracted to an R temporary folder, not into the repository.

The second script reads the county results and boundary ZIP and saves two self-contained interactive HTML maps. HTML export requires Pandoc, which is included with RStudio. The maps support county information on hover, click-to-open popups, dragging, and zoom buttons. They have no external basemap tiles and work offline after generation.

The code checks for 67 distinct counties, missing values, and matching geographic codes. It also checks county population sums against the official Pennsylvania totals and verifies that natural change, net migration, and the residual sum to population change for each county.

## Main findings

Twenty-six counties grew and 41 declined; 59 had natural decrease and 45 had positive net migration. Nineteen counties grew despite natural decrease, while 19 declined despite positive net migration. State population increased by 56,679 (about 0.44%). These figures apply to the included Vintage 2025 snapshot.

## Sources and definitions

### Population estimates

U.S. Census Bureau, Population Division. **Vintage 2025: CO-EST2025-ALLDATA**, released March 2026.

- [Dataset landing page](https://www.census.gov/data/tables/time-series/demo/popest/2020s-counties-total.html)
- [Original CSV](https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/counties/totals/co-est2025-alldata.csv)
- [Official field definitions](https://www2.census.gov/programs-surveys/popest/technical-documentation/file-layouts/2020-2025/CO-EST2025-ALLDATA.pdf)
- [Population-estimates methodology](https://www.census.gov/programs-surveys/popest/technical-documentation/methodology.html)

Pennsylvania counties are identified by `STATE == 42` and `SUMLEV == 50`. `SUMLEV == 40` supplies the state total for validation. The five-character geographic key combines the two-digit state and three-digit county FIPS codes.

| Field | Use |
| --- | --- |
| ESTIMATESBASE2020 | April 1, 2020 population estimates base; denominator |
| POPESTIMATE2025 | July 1, 2025 population estimate |
| BIRTHS2020–2025, DEATHS2020–2025 | Cumulative births and deaths |
| DOMESTICMIG2020–2025 | Cumulative net movement between the county and elsewhere in the United States |
| INTERNATIONALMIG2020–2025 | Cumulative net international migration |
| RESIDUAL2020–2025 | Population change not assigned to the other components |
| NATURALCHG2020–2025, NETMIG2020–2025 | Independent checks against computed component totals |

The 2020 component covers April–June 2020; the following five fields cover July–June intervals through 2025. Summing all six fields matches the April 2020 base to the July 2025 endpoint. All population estimates and components come from the same vintage.

### County boundaries

U.S. Census Bureau. **2023 Cartographic Boundary File, counties, 1:5,000,000**, [original ZIP](https://www2.census.gov/geo/tiger/GENZ2023/shp/cb_2023_us_county_5m.zip).

Pennsylvania boundaries (`STATEFP == "42"`) are joined to the population table by `GEOID`. All 67 county codes match. These simplified 2023 polygons provide the display geography; the estimates use January 2025 geography. The analysis checks geographic codes rather than detailed boundary changes. Static maps use NAD83 / Conus Albers (EPSG:5070), an equal-area coordinate system. No area-based rate is calculated.

## Calculations and map design

- Population change = July 2025 estimate minus April 2020 estimates base.
- Natural change = cumulative births minus cumulative deaths.
- Net migration = cumulative domestic plus international net migration.
- Growth (%) = 100 × population change / April 2020 base.
- Each component's contribution (percentage points) = 100 × cumulative component / April 2020 base.

These are cumulative measures over 5.25 years, not annual growth rates and not Census's published annual per-1,000 migration rates. State growth uses summed counts, not the unweighted average of county rates. Domestic migration includes moves within Pennsylvania as well as between states; it is not a count of people arriving from other states alone.

The maps share a continuous orange-to-blue scale centered on zero with identical limits. Orange indicates a decrease or net outflow, blue an increase or net inflow. Static map labels locate the six counties examined in figure 3. Static maps use the equal-area projection described above; interactive maps use Leaflet's Web Mercator display, with county geometry supplied in longitude/latitude. Larger polygons represent land area, not population size. Missing values are checked rather than silently dropped or replaced by zero.

Figure 3 uses Pike (highest growth), Cumberland (second-highest growth), Butler (western growth example), Westmoreland (decline despite inflow), Philadelphia (domestic and international flows in opposing directions), and Cameron (largest percentage decline). These are illustrative, deliberately selected contrasts, not a representative sample. Positive and negative components stack separately; a diamond marks their net total. Residuals remain visible and are included in all calculations.

## Interpretation limits

The analysis describes estimated population accounting, not causal effects of migration or the reasons people move. Net flows do not reveal gross arrivals/departures or origin-destination links. County totals hide within-county differences; a large percentage change in a small county can reflect relatively few people. The cumulative period includes the pandemic and does not show each year's trajectory. Estimates are revised across vintages; no confidence intervals are supplied in this analysis.

## Related article

The [blog article source](https://github.com/annzhao-77/website/blob/main/blog/posts/post5/index.qmd) is maintained in the separate website repository, alongside copies of the figures and interactive maps. This repository contains the data, analysis code, and results supporting that article.
