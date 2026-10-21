# =====================================================================
# run_all.R
# Runs the whole analysis from start to finish, then builds the report.
# Open bo-rice-climate.Rproj in RStudio, then run:   source("R/run_all.R")
# =====================================================================

# Start clean, so nothing left over from earlier work affects the results
rm(list = ls())
if (file.exists("output/example_data_used.txt")) file.remove("output/example_data_used.txt")

# Make the example data if they are not there yet
if (!dir.exists("data/example")) source("R/make_example_data.R")

source("R/01_load_clean.R")
source("R/02_rainfall.R")
source("R/03_vegetation.R")
source("R/04_yield_models.R")
source("R/05_prices.R")

# Build the report (needs Quarto, which comes with recent RStudio)
if (nzchar(Sys.which("quarto"))) {
  system("quarto render report/report.qmd")
  message("Report written to report/report.html and report/report.docx")
} else {
  message("Quarto not found. Open report/report.qmd in RStudio and click 'Render'.")
}

writeLines(capture.output(sessionInfo()), "output/session_info.txt")
message("All done.")
