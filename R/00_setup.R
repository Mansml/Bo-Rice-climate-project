# =====================================================================
# 00_setup.R
# Loads packages, sets shared settings, and defines where data live.
# Every other script starts with  source("R/00_setup.R").
# =====================================================================

# ---- 1. Packages -----------------------------------------------------
# The first time you run this, missing packages are installed for you.
packages <- c(
  "readr",        # reading CSV files
  "dplyr",        # filtering, grouping, summarising tables
  "tidyr",        # reshaping tables (long <-> wide)
  "lubridate",    # working with dates
  "stringr",      # working with text
  "zoo",          # rolling (moving-window) calculations
  "ggplot2",      # graphs
  "patchwork",    # putting several graphs side by side
  "scales",       # nicer axis labels
  "sf",           # maps / vector spatial data (boundaries)
  "terra",        # raster spatial data (satellite images)
  "randomForest"  # random forest machine-learning model
)

missing_packages <- packages[!packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

# We attach the packages we use all the time. terra and randomForest are
# NOT attached; we call them as terra::rast() and randomForest::randomForest()
# so their function names do not clash with dplyr's.
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)
library(ggplot2)
library(patchwork)
library(sf)

# ---- 2. Folders ------------------------------------------------------
# Paths are relative to the project folder. Always open the project by
# double-clicking  bo-rice-climate.Rproj  so R starts in the right place.
for (folder in c("data/raw", "data/processed", "output/figures", "output/tables")) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

# ---- 3. Where is each dataset? ---------------------------------------
# If a real file is in data/raw/ we use it. If not, we fall back to the
# made-up example file in data/example/ so the code still runs.
# The report prints a warning whenever example data were used.
if (!exists("EXAMPLE_DATA_USED")) EXAMPLE_DATA_USED <- character(0)

data_file <- function(file_name) {
  real_path    <- file.path("data/raw", file_name)
  example_path <- file.path("data/example", file_name)
  if (file.exists(real_path)) {
    return(real_path)
  }
  if (!file.exists(example_path)) {
    stop("Could not find ", file_name, " in data/raw/ or data/example/.\n",
         "Run source('R/make_example_data.R') or add the real file.")
  }
  message("NOTE: using EXAMPLE (made-up) data for ", file_name)
  EXAMPLE_DATA_USED <<- unique(c(EXAMPLE_DATA_USED, file_name))
  writeLines(EXAMPLE_DATA_USED, "output/example_data_used.txt")
  example_path
}

# ---- 4. Study settings (change these if you need to) -----------------
BASELINE_YEARS <- 1991:2020   # the standard 30-year climate "normal"
RECENT_YEARS   <- 2016:2025   # "the last ten years" that farmers talk about
FIRST_YEAR     <- 1981
LAST_YEAR      <- 2025

# ---- 5. One look for every graph -------------------------------------
# Colours (colour-blind-checked): blue, orange, aqua, plus neutral greys.
COL_BLUE   <- "#2a78d6"
COL_ORANGE <- "#eb6834"
COL_AQUA   <- "#1baf7a"
COL_GREY   <- "#8c8b86"
COL_INK    <- "#0b0b0b"
COL_INK2   <- "#52514e"

theme_project <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title       = element_text(face = "bold", colour = COL_INK),
      plot.subtitle    = element_text(colour = COL_INK2),
      plot.caption     = element_text(colour = COL_INK2, size = 8, hjust = 0),
      axis.text        = element_text(colour = COL_INK2),
      axis.title       = element_text(colour = COL_INK2),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#e6e5e0", linewidth = 0.3),
      strip.text       = element_text(face = "bold", colour = COL_INK, hjust = 0),
      legend.position  = "top",
      legend.title     = element_blank(),
      plot.background  = element_rect(fill = "white", colour = NA)
    )
}

save_figure <- function(plot, file_name, width = 8, height = 5) {
  ggsave(file.path("output/figures", file_name), plot,
         width = width, height = height, dpi = 300, bg = "white")
  message("Saved figure: output/figures/", file_name)
}

source("R/functions.R")
