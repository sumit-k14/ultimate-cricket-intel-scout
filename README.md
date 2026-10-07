# 🏏 The Ultimate Multi-Format Cricket Intel Scout

A dynamic and interactive R Shiny web application designed to visualize, analyze, and benchmark performance metrics for various global cricket players across multiple match formats.

The application is deployed and hosted live on cloud servers like *shinyapps.io*

---

## 🚀 Live Demo
You can view and interact with the deployed application here:
👉 https://01a111ef-c0b4-b26c-858f-d44a72e59876.share.connect.posit.cloud/

---

## ✨ Features

# 1. Interactive Sidebar Controls
  *• Category Selection:* A dropdown menu allowing users to switch dynamically between "Male" and "Female" cricket databases.
  *• Player Comparison:* A multi-select dropdown search field to isolate and compare up to 6 specific players simultaneously.
  *• Match Format Scope:* Reactive choice filters to isolate specific scopes including All Formats, Tests, ODIs, International T20, and domestic leagues (IPL/WPL).
  *• Dynamic Runs Filter:* A responsive slider input to filter the database across custom minimum career run benchmarks.
  *• Live Repository Sync:* A dedicated operational route to download fresh datasets and recalculate advanced statistics instantly.

# 2. Rich Data Visualizations
  *• Impact Matrix (Runs vs Strike Rate):* A scatter plot mapping total runs against batting strike rates to isolate high-volume boundary hitters from traditional anchor players.
  *• Batting Average Comparison:* A horizontal bar chart organizing tournament formats with tailored, high-contrast color profiles (Gold for Tests, Steel Blue for ODIs, Slate for T20s, and Emerald for IPL/WPL).
  *• Milestone Distribution:* A faceted stacked bar chart isolating individual format-level hundreds (100s) and fifties (50s) distribution frequencies.
  *• Career Longevity Tracker:* A faceted column chart mapping player career longevity by measuring absolute multi-format active year ranges.

# 3. Advanced Player Scout Scorecard
  • An interactive, searchable, and sortable data table providing core metrics for selected datasets:
	• Matches & Innings active volume metrics.
	• Total cumulative Runs.
	• Calculated metrics like Average (Runs per dismissal) and Strike Rate rounded precisely to 2 decimal boundaries.
	• Raw milestone counters (100s & 50s).

---

## 📊 Data Source

The dashboard is powered by a multi-layered data pipeline that dynamically manages real-time repository ingestion and updates local cache records:

*• International Feeds:* Automated match statistics fetched directly via official international cricket archives.
*• Domestic Leagues:* Ball-by-ball processing scripts running across domestic league datasets.
*• Cache Architecture:* cricket_master_multi_male.csv and cricket_master_multi_female.csv local storage buckets ensuring optimized application boot cycles under 2 seconds.

---

## 🛠️ Tech Stack & Dependencies

This application is split into a clean modular architecture (ui.R, server.R, global.R etc) and is built entirely using the R programming language ecosystem. Key packages utilized include:

• `shiny` & `bslib` - For modern card-pill responsive application layouts and custom typography.
• `ggplot2`, `plotly` - For static themes and custom dark-slate interactive tooltip rendering.
• `dplyr`, `tidyr`, `stringr`, `readr` - For data cleaning, string squishing, filtering, and aggregation loops.
• `cricketdata` - For live API database connection triggers.
• `DT` - For rendering the interactive, server-side data summary table.

---

## 💻 Local Installation & Setup

To run this dashboard locally on your machine, follow these steps:

### Prerequisites
Make sure you have [R](https://r-project.org) and [RStudio](https://posit.co) installed.

### 1. Clone the Repository
```bash
git clone https://github.com
cd cd cricket-intel-scout
```

### 2. Install Required R Packages
Open R or RStudio and execute the following script to install all needed dependencies:
```R
install.packages(c("shiny", "bslib", "dplyr", "tidyr", "stringr", "ggplot2", "readr", "DT", "cricketdata", "plotly"))
```

### 3. Run the App
Place your modular scripts (ui.R and server.R) into the project root folder, launch RStudio, and run:
```R
shiny::runApp()
```

---

## 🌐 Deployment to Posit Connect

This application is configured for cloud deployment. To redeploy or host your own instance:
1. Initialize the deployment manifest via `rsconnect::writeManifest()`.
2. Connect your RStudio IDE to your *Posit Connect Cloud* account.
3. Click the *Publish* button at the top right of your RStudio viewer window.


## 🌐 Deployment to shinyapps.io

This multi-file application is optimized for cloud deployment. To host your live instance:
1. Connect your local RStudio IDE to your *shinyapps.io* account using your account token strings.
2. Load the `rsconnect` library: library(rsconnect).
3. Publish your code with a single command line: 
```R
rsconnect::deployApp(appName = "cricket-intel-scout")
```