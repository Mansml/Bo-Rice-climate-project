---
title: "Build It Yourself: a step-by-step guide"
subtitle: "Bo District rice & climate project in R, for beginners"
format:
  html:
    toc: true
    toc-depth: 2
    number-sections: true
    embed-resources: true
---

# Read this first

This guide walks you through building the whole project yourself, one small step at a time. A finished, working version is also in this folder, so you can always compare your code with it.

**How to use the two together:**

- Build each script yourself by following this guide. **Type the code; don't copy and paste it.** Typing is how you learn it.
- When you get stuck, open the matching file in the `R/` folder and compare.
- At every **✅ Checkpoint**, stop and make sure your result looks right before moving on.
- The **💬 Be ready to explain** boxes are things a professor may ask you in an interview. If you can answer them in your own words, you understand the project.

**Be honest about what you did.** In your CV and statement, describe this as your own project only once you can explain every step. The interview questions in Section 13 are a good test.

**Time plan (part-time):**

| Week | What you do |
|---|---|
| 1 | Set-up, R refresher, download all data (Sections 2–4) |
| 2 | Cleaning + Part A rainfall (Sections 5–6) |
| 3 | Part B vegetation + Part C yield models (Sections 7–8) |
| 4 | Part D prices, report, GitHub, interview practice (Sections 9–14) |

---

# Set up your computer

## Install the software

1. **R**: https://cran.r-project.org. Choose your system (Windows or Mac) and install the latest version.
2. **RStudio Desktop** (free): https://posit.co/download/rstudio-desktop/. This is the program you'll actually work in. It already includes **Quarto**, which builds the report.
3. **A Google account**, which you need for Google Earth Engine and Google Drive.
4. **A GitHub account** (free): https://github.com, where your finished project will live.

## Make the project folder

1. Copy the whole `bo-rice-climate` folder somewhere easy to find, such as `Documents`.
2. Double-click **`bo-rice-climate.Rproj`**. RStudio opens *inside* the project.

> **Why this matters:** when RStudio is opened through the `.Rproj` file, R knows where your project is, so paths like `"data/raw/file.csv"` just work. **Always open the project this way.**

## Know your way around RStudio

| Panel | What it is |
|---|---|
| Top left: **Source** | Where you write and save scripts (`.R` files) |
| Bottom left: **Console** | Where code runs and results/errors appear |
| Top right: **Environment** | The objects (tables, numbers) you have created |
| Bottom right: **Files / Plots / Help** | Your folders, your graphs, help pages |

**Running code:** put your cursor on a line and press **Ctrl + Enter** (Mac: **Cmd + Enter**) to run that line. Select several lines and press the same keys to run them all.

✅ **Checkpoint:** In the Console, type `getwd()` and press Enter. It should print a path ending in `bo-rice-climate`.

---

# A 30-minute R refresher

Run each line in the Console and watch what happens. These are the only building blocks this project uses.

```r
# 1. Objects: store a value with <-
rain_today <- 12.5
rain_today * 2

# 2. Vectors: several values in one object
rain_week <- c(0, 0, 5.2, 12.1, 0, 3.4, 20)
sum(rain_week)       # total
mean(rain_week)      # average
max(rain_week)       # wettest day
rain_week >= 1       # TRUE/FALSE: which days were rainy?
sum(rain_week >= 1)  # count of rainy days (TRUE counts as 1)
rain_week[3]         # the 3rd value
rain_week[2:4]       # values 2 to 4

# 3. Data frames (tables)
library(dplyr)
farms <- tibble(
  farmer = c("A", "B", "C", "D"),
  system = c("upland", "swamp", "swamp", "upland"),
  yield  = c(1.2, 2.1, 1.8, 0.9)
)
farms

# 4. The pipe %>% means "and then"
farms %>%
  filter(system == "swamp") %>%           # keep some rows
  mutate(yield_kg = yield * 1000)         # add a column

farms %>%
  group_by(system) %>%                    # split into groups
  summarise(mean_yield = mean(yield))     # one summary row per group

# 5. Your own function
double_it <- function(x) {
  x * 2
}
double_it(10)

# 6. A for loop: repeat something for each value
for (yr in 2020:2022) {
  print(paste("Processing year", yr))
}

# 7. A graph
library(ggplot2)
ggplot(farms, aes(x = system, y = yield)) +
  geom_point(size = 3)
```

If any `library()` line gives an error, install the package first with `install.packages("dplyr")` (or whichever name it gives).

✅ **Checkpoint:** You can explain what `%>%`, `filter()`, `mutate()`, `group_by()` and `summarise()` do.

---

# Get the data

You need four kinds of data. The satellite data come from Google Earth Engine. Yields and prices are plain downloads.

## Google Earth Engine (rainfall, vegetation, boundaries)

**What it is:** Google Earth Engine (GEE) is a free platform that stores petabytes of satellite data and lets you process them on Google's computers. You will use it only to *extract* data. All analysis happens in R.

**One-time registration:**

1. Go to https://earthengine.google.com and click **Get Started**.
2. Register for **non-commercial / research use**. It asks you to create a **Google Cloud project**. Give it any name, such as `bo-rice`. This is free.
3. When it's done, open the **Code Editor**: https://code.earthengine.google.com

**Run the export script:**

1. Open `gee/01_export_data.js` from the project folder in a text editor (Notepad works). Copy all of it.
2. Paste it into the middle panel of the Code Editor and click **Run**.
3. Look at the **Console** tab on the right:
   - *"Number of Bo polygons found"* should be **1**. If it is 0, look at the printed list of district names and change `'Bo'` in the script to the exact spelling shown.
   - *"Farmland pixels in Bo"* should be at least a few hundred. If it is very small, change `FARM_THRESHOLD = 0.5` to `0.3` and click Run again.
4. The map shows Sierra Leone with Bo in red. Click the **Layers** button on the map to see the greenness layer.
5. Open the **Tasks** tab on the right. You will see **5 tasks**. Click **RUN** on each one, then **Run** in the pop-up window.
6. Wait. The rainfall task can take 10–40 minutes. You can close the browser; the tasks keep running.
7. Open **Google Drive** and go to the folder **`bo_rice_project`**. Download all 5 files into `data/raw/` in your project.

💬 **Be ready to explain:** *What is CHIRPS?* It is a rainfall dataset that combines satellite infrared observations with rain-gauge records. It gives daily rainfall at about 5 km resolution from 1981, which is why it is widely used in Africa where gauges are sparse. *What is NDVI?* It measures greenness from how plants reflect red and near-infrared light: (NIR − Red) / (NIR + Red). Healthy, dense vegetation reflects a lot of near-infrared, so it scores high.

## FAOSTAT (national rice yield)

Follow the steps in `data/raw/README.md`: Sierra Leone → Yield → Rice → all years → CSV. Rename the file to **`faostat_rice_yield_sle.csv`**.

## WFP prices (Bo market)

Download the CSV from https://data.humdata.org/dataset/wfp-food-prices-for-sierra-leone and name it **`wfp_food_prices_sle.csv`**.

✅ **Checkpoint:** `data/raw/` contains 7 files with exactly the names listed in `data/raw/README.md`.

> **Can't get the data yet?** No problem. Run `source("R/make_example_data.R")` and the code will use made-up practice files until the real ones are in place. The report will warn you whenever that happens.

---

# Script 00 (setup) and Script 01 (cleaning)

## Script 00: setup

Create a new script (**File → New File → R Script**) and save it as `R/00_setup.R`. This script loads the packages and settings that every other script needs. Build it in this order, looking at the finished version when needed:

1. A vector of package names, and code that installs any that are missing
2. `library()` lines for the packages
3. `dir.create()` lines that make the `output/` folders
4. The settings, `BASELINE_YEARS <- 1991:2020` and `RECENT_YEARS <- 2016:2025`
5. Colours and a `theme_project()` function so all graphs look the same
6. `source("R/functions.R")` at the end. You'll write that file in Section 6.

> **Shortcut that's fine to take:** the `data_file()` function (the example-data fallback) is a convenience. Copy it from the finished version and read the comments; you don't need to build it from scratch.

## Script 01: load and clean

Save a new script as `R/01_load_clean.R`. Start it with:

```r
source("R/00_setup.R")
```

**Step 1: read the rainfall and look at it.**

```r
rain_raw <- read_csv("data/raw/chirps_daily_bo_sle.csv")
head(rain_raw)          # first 6 rows
summary(rain_raw)       # min, max, mean of each column
table(rain_raw$region)  # how many rows per region?
```

✅ **Checkpoint:** There should be two regions ("Bo" and "Sierra Leone") with about 16,400 rows each, one per day for 45 years.

**Step 2: check for problems.** Real data always need checking. Ask three questions, and write code to answer each:

- **Duplicates?** `sum(duplicated(rain_raw[, c("region", "date")]))`
- **Missing days?** Build the full calendar with `expand_grid()`, join your data to it, and count the `NA`s.
- **Impossible values?** Negative rainfall can't happen: `sum(rain_raw$rain_mm < 0)`

**Step 3: clean the other three datasets.** Follow the finished script. The key ideas are:

| Dataset | Cleaning step | Why |
|---|---|---|
| NDVI | `share_clear = n_good_pixels / n_farm_pixels`, keep if ≥ 0.30 | Clouds hide the land. An image where 95% of farmland is cloudy tells you about clouds, not crops. |
| Yield | Convert to t/ha from `kg/ha` or `hg/ha` | FAOSTAT changed its units, so check the `Unit` column. |
| Yield | Keep the `Flag` column | "E" or "I" flags mean the value was **estimated**, not measured. This matters for your limitations. |
| Prices | Remove the `#tags` row | The HDX file has a second header row starting with `#`. |
| Prices | Divide old Leones (SLL) by 1000 | Sierra Leone re-denominated in 2022: 1 SLE = 1000 SLL. Without this, prices look like they crashed by 99.9% overnight. |

Each cleaned table is saved with `write_csv()` into `data/processed/`.

✅ **Checkpoint:** `data/processed/` contains `rain_daily.csv`, `ndvi_16day.csv`, `yield_national.csv` and `prices_monthly.csv`. Open each one by clicking it in the Files panel → **View File**.

💬 **Be ready to explain:** *Why keep cleaning in one separate script?* Every later step reads the same cleaned files, so cleaning decisions are made once, in one visible place. Anyone can check them.

---

# Part A: rainfall (the core of the project)

The idea is to turn 16,000 days of rain into a few meaningful numbers per year that a farmer would recognise: **When did the rains really start? Was there a dry spell after planting? How wet was the season? Was there flooding rain?**

## Build the functions one at a time

Create `R/functions.R`. Build **one function, test it on a tiny example, and only then move on.** This is how professionals write reliable code.

**Function 1: longest dry spell.**

```r
longest_dry_spell <- function(rain, dry_threshold = 1) {
  is_dry <- rain < dry_threshold
  if (!any(is_dry)) return(0)
  runs <- rle(is_dry)
  max(runs$lengths[runs$values])
}
```

`rle()` ("run length encoding") turns `TRUE TRUE FALSE TRUE TRUE TRUE` into "2 TRUEs, then 1 FALSE, then 3 TRUEs". We take the longest run of TRUEs, which is the longest run of dry days.

Test it. You know what the answers should be:

```r
longest_dry_spell(c(0, 0, 5, 0, 0, 0, 2))   # should be 3
longest_dry_spell(c(5, 5, 5))               # should be 0
longest_dry_spell(c(0, 0, 0, 0))            # should be 4
```

✅ **Checkpoint:** All three answers are correct.

**Function 2: onset of the rains.** The rule is a standard West African definition (Sivakumar, 1988). Starting from 1 April, onset is the first day where:

- the next 3 days bring at least 20 mm, with at least 2 rainy days, **and**
- no dry spell of 7 or more days follows in the next 30 days.

The second condition rules out a **false start**: rain that tempts farmers to plant, followed by a dry spell that kills the seedlings. Farmers know this problem well, and that's exactly why the rule exists.

Write `find_onset()` using a `for` loop that checks each day from 1 April (see the finished version). Then **test it on one real year and look at it:**

```r
rain <- read_csv("data/processed/rain_daily.csv")
bo   <- filter(rain, region == "Bo")

i <- find_onset(bo$rain_mm, bo$date, 2020)
bo$date[i]                                     # the onset date in 2020

# Plot 2020 and draw a line at the onset date
bo %>%
  filter(year(date) == 2020, month(date) %in% 3:7) %>%
  ggplot(aes(date, rain_mm)) +
  geom_col() +
  geom_vline(xintercept = bo$date[i], colour = "red")
```

✅ **Checkpoint:** Does the red line sit where the rains clearly begin? Try a few other years. If the onset looks wrong, find out why before going on.

**Functions 3 to 5.** Build these in the same way: write it, test it on a small example, then look at a real year.

- `find_cessation()`: the end of the season
- `rainfall_indices()`: loops over every year and returns one row per year
- `spi_from_totals()`: the Standardised Precipitation Index

**Functions 6 and 7: the trend tests.** Write these last.

- `mann_kendall()`
- `sens_slope()`

If you have the `trend` package, check that your answers match: `trend::mk.test(x)` and `trend::sens.slope(x)`.

## The rainfall indices explained

| Index | Plain meaning | Why a rice farmer cares |
|---|---|---|
| Onset date | When reliable rains start | Planting date; a late onset shortens the season |
| End of season | When rains stop | Whether the crop finishes filling grain |
| Season length | Days from onset to end | Which varieties can be grown |
| Dry spell after onset | Longest dry run in the first 40 days | Seedlings die in dry spells, so farmers must replant |
| May–Oct total | Total rain in the main season | Overall water supply |
| Wettest 5 days (Rx5day) | Biggest 5-day downpour | Flooding of swamps and valley bottoms |
| Very heavy rain days | Days above the 95th percentile | How often there are extreme downpours |
| SPI | How unusual the season total was, on a standard scale | Drought (SPI below −1) or very wet years (above +1) |

## Trend tests

**Mann–Kendall** asks: *is there a steady upward or downward trend?* It compares every pair of years (1981 vs 1982, 1981 vs 1983, … 2024 vs 2025) and counts how often the later year is higher or lower. If "higher" wins by much more than chance would allow, there's an upward trend.

**Sen's slope** asks: *how big is the trend?* It takes the median of the slopes between every pair of years. Because it uses the median, one extreme year can't distort it.

💬 **Be ready to explain:** *Why not just fit a straight line with `lm()`?* Rainfall data are often skewed and contain extreme years. Mann–Kendall and Sen's slope make no assumption about the shape of the data and are robust to outliers, which makes them the standard tools in climate trend analysis.

💬 **Be ready to explain:** *Some indices show a slope of exactly 0. Is that a bug?* No. Counts like dry-spell days are whole numbers, so many pairs of years have the same value, and the median slope is often exactly 0. The p-value still tells you whether there's evidence of a trend.

## Make the figures

Write `R/02_rainfall.R` following the finished version. It produces three figures:

- **A1:** the shape of the rainy season, 1991–2020 compared with 2016–2025
- **A2:** four indices over time, with trend lines
- **A3:** what farmers told you next to what the data show

A3 is the heart of the project. **Your own survey sits next to 45 years of satellite data.**

✅ **Checkpoint:** Three PNG files are in `output/figures/`, and `output/tables/rainfall_trends_bo.csv` exists. Open the CSV and read it: which indices have p < 0.05?

---

# Part B: vegetation

Write `R/03_vegetation.R`. It does four things:

1. **Show the seasonal greenness cycle** (Figure B1). The bottom panel shows how often clouds hid the land. **You'll see a big gap from July to September**, exactly when rice is growing. This isn't a mistake in your code. It is a real, well-known problem for optical satellites in humid West Africa, and an important point for your limitations section.
2. **Calculate late-season greenness for each year.** Use October to December, when skies clear and the crop is near harvest.
3. **Correlate it with that year's rainfall indices** (Figure B2). Use **Spearman** correlation as well as Pearson, because with only about 26 years one unusual year can drive a Pearson correlation.
4. **Make the maps** (Figure B3):
   - `st_read()` reads the boundaries
   - `terra::rast()` reads the satellite image
   - `as.data.frame(xy = TRUE)` turns pixels into a table that ggplot can draw

✅ **Checkpoint:** Look at Figure B1. When is farmland greenest? When is it least visible?

💬 **Be ready to explain:** *How would you fix the cloud problem?* With **radar** satellites such as Sentinel-1. Radar sees through clouds and is sensitive to standing water, so it can map flooded rice fields. That makes it a strong next step, and a natural link to a PhD.

---

# Part C: yield models (statistics vs machine learning)

## Step 1: remove the trend

Plot the yields first (Figure C1). National yields drift slowly over time because of the civil war, policy changes and new varieties. Weather causes the *year-to-year wiggles* around that drift.

So we fit a smooth curve (LOESS) and keep the **anomaly**, the percentage above or below the curve. That anomaly is what we try to explain with rainfall.

## Step 2: understand cross-validation before you code it

Imagine you have 43 years of data.

- Hide **one** year, say 1995.
- Train the model on the other 42 years.
- Predict 1995 and write down the error.
- Repeat for every year.

This is **leave-one-year-out cross-validation**. Every prediction is made for a year the model has never seen, which is the honest test of whether it could predict *next* season.

You compare three models:

| Model | What it is | Why include it |
|---|---|---|
| No-skill baseline | Always predicts the average | Any useful model must beat this |
| Linear regression | Straight-line relationships | Simple and easy to interpret |
| Random forest | Many decision trees averaged together | Can capture non-linear effects and interactions |

Write the loop yourself. It's just a `for` loop over rows, fitting all three models inside it.

## Step 3: read the results carefully

**Expect the random forest *not* to win.** With about 40 data points, a flexible model learns noise (this is called **overfitting**). That isn't failure. Showing it clearly is good science.

When you test the code on the example data, you'll see something striking. The regression on the full data shows two "significant" coefficients (p < 0.05), but in cross-validation it predicts **no better than the average**. **The example data are pure random numbers**, so those "significant" results are false. This is exactly why cross-validation matters, and it makes an excellent interview story.

✅ **Checkpoint:** Open `output/tables/model_scores.csv`. Which model has the lowest RMSE? Did any model beat the baseline?

💬 **Be ready to explain:**

- *What is RMSE?* Root-mean-square error: the typical size of a prediction error, in the same units as the data (here, percentage points of yield).
- *Why not just use R²?* R² on the training data always improves as you add variables, even useless ones. Error on unseen data can't be fooled that way.
- *Why are national yields a weak test?* They average upland and swamp systems across the whole country, many values are estimates, and yields also depend on inputs, pests and prices. District-level or field-level yields would be far better, and collecting them would be a PhD contribution.

---

# Part D: prices

Write `R/05_prices.R`.

**The problem:** Sierra Leone's prices rise a lot every year because of inflation, which hides the seasonal pattern.

**The fix:** divide each month's price by the average price over the 12 months around it. A value of 1.08 means "8% above that year's price level". This is the **seasonal index**.

Then:

1. Average the index by calendar month (Figure D1). This shows when rice is cheapest (just after harvest) and most expensive (the lean season).
2. Calculate each year's **lean-season premium**: the July–September index minus the previous October–December index.
3. Check whether the premium is bigger after a poor rainy season (Figure D2).

**Link this to your thesis.** You found that 20% post-harvest losses and distress sales hurt farmers' incomes. Figure D1 puts a number on how much farmers lose by selling at harvest and buying back in the lean season.

✅ **Checkpoint:** In which month are local rice prices highest? Lowest? How big is the swing?

---

# The report

Open `report/report.qmd` and click **Render** at the top of the editor. RStudio builds `report.html` and `report.docx`.

The numbers in the report fill in **automatically** from your results tables. For example, `` `r num(tr("onset_doy")$p_value)` `` pulls the p-value straight from the CSV, so the text always matches the analysis.

**Your job is to write the parts marked ✍️.** These are the interpretations: what the results mean for Bo's farmers. Nobody else can write them as well as you, because you know these farmers. Keep each one to 3–5 sentences.

- Say what the data show.
- Say whether it agrees with what farmers reported.
- Give a possible reason for any difference.

✅ **Checkpoint:** The report renders with **no "Example data in use" warning at the top**. If you see the warning, a real data file is missing from `data/raw/`.

---

# Make it reproducible

## One button runs everything

Run the whole project with:

```r
source("R/run_all.R")
```

It cleans the data, runs Parts A–D, and builds the report. If it runs from start to finish without errors, your project is reproducible.

## Lock package versions with renv (optional but impressive)

```r
install.packages("renv")
renv::init()       # records exactly which package versions you used
```

This creates a `renv.lock` file. Anyone can recreate your exact setup with `renv::restore()`.

## Put it on GitHub

The easiest way is **GitHub Desktop** (https://desktop.github.com):

1. In GitHub Desktop, choose **File → Add local repository** and select your project folder. Let it create a repository.
2. Write a short summary, such as "First version", and click **Commit to main**.
3. Click **Publish repository**. Untick "Keep this code private" if you want professors to see it.

**Check before publishing:** the real data files can be large. A `.gitignore` file is included that leaves out `data/raw/` and `data/processed/`. People can re-download the data using your README instructions.

✅ **Checkpoint:** Your GitHub page shows the README, the `R/` folder and the figures.

---

# Common errors and what they mean

| Error message | What it means | Fix |
|---|---|---|
| `could not find function "..."` | Package not loaded | Run `source("R/00_setup.R")` first |
| `there is no package called '...'` | Package not installed | `install.packages("name")` |
| `'data/raw/...' does not exist` | Wrong folder or file name | Open the project via the `.Rproj` file; check the exact file name |
| `object '...' not found` | You skipped an earlier line | Run the script from the top |
| Onset is `NA` for many years | The rule found no valid onset | Plot those years. Is the data right? Is 1 April too late for Bo? |
| Graph looks empty | Filtered everything out | Check with `nrow()` after each `filter()` |

**The golden rule:** when something breaks, run the code **line by line** and look at the result of each line, using `head()`, `nrow()` and `summary()`. The problem is always at the first line that gives something unexpected.

---

# Interview practice

Try answering these aloud in 1–2 minutes each, without notes.

1. **Tell me about this project.** Cover the question, the data, the methods, the main finding and the main limitation.
2. **Why did you define onset that way?** It follows Sivakumar (1988), a standard agronomic rule for West Africa. The dry-spell condition excludes false starts that kill seedlings.
3. **What is the difference between Mann–Kendall and linear regression?**
4. **Why use leave-one-year-out cross-validation?**
5. **Your random forest didn't beat regression. Why not?**
6. **What would you do with more time or better data?** Possible answers:
   - district or field yields
   - radar (Sentinel-1) to see through clouds and map swamp flooding
   - separating upland from swamp rice
   - a crop model such as DSSAT, APSIM or ORYZA
7. **How does your fieldwork help you as a data scientist?** You know which rainfall features matter to farmers (false starts, dry spells, swamp floods), so you could choose indices that mean something on the ground. You can also judge when satellite data and farmers' reports disagree.
8. **What surprised you in the results?** Answer from your real results.

**Key terms to know:**

- CHIRPS
- NDVI and EVI
- onset
- dry spell
- Rx5day
- SPI
- Mann–Kendall
- Sen's slope
- detrending
- anomaly
- overfitting
- cross-validation
- RMSE
- random forest
- variable importance
- seasonal index
- process-based crop model

---

# Final checklist

- [ ] All 7 real data files are in `data/raw/`
- [ ] `source("R/run_all.R")` runs without errors
- [ ] The report has **no** example-data warning
- [ ] All ✍️ boxes are replaced with my own interpretation
- [ ] I can explain every figure in my own words
- [ ] I've looked at the onset dates for at least five years by eye
- [ ] The project is on GitHub with a clear README
- [ ] My CV describes what I actually did, specifically. For example: *"Built a reproducible R pipeline analysing 45 years of CHIRPS rainfall and MODIS NDVI for Bo District; computed agronomic onset, dry-spell and SPI indices; tested trends (Mann–Kendall, Sen's slope); compared linear regression and random forest yield models using leave-one-year-out cross-validation."*
