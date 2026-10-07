# ============================================================
# PACKAGES & ENVIRONMENT SETUP
# ============================================================
library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(readr)
library(DT)
library(cricketdata)
library(plotly) # For interactive web elements

# Resolve namespace conflicts explicitly.
if (requireNamespace("conflicted", quietly = TRUE)) {
  conflicted::conflicts_prefer(
    dplyr::filter, dplyr::select, dplyr::mutate, dplyr::summarise,
    dplyr::arrange, dplyr::group_by, dplyr::left_join, dplyr::distinct,
    dplyr::rename, dplyr::count
  )
}

# ============================================================
# 2. CACHE FILES CONFIGURATION
# ============================================================
CACHE_MALE <- "cricket_master_multi_male.csv"
CACHE_FEMALE <- "cricket_master_multi_female.csv"

# ============================================================
# 3. HELPER ATOMIC SANITATION FUNCTIONS
# ============================================================
safe_numeric <- function(x) suppressWarnings(as.numeric(x))
safe_integer <- function(x) suppressWarnings(as.integer(x))

empty_cricket_table <- function() {
  tibble::tibble(
    Player = character(),
    Format = character(),
    Matches = integer(),
    Innings = integer(),
    Runs = integer(),
    Ave = numeric(),
    SR = numeric(),
    X100 = integer(),
    X50 = integer(),
    Start_Year = integer(),
    End_Year = integer()
  )
}

# ============================================================
# 4. CLEAN CRICINFO INTERNATIONAL DATAFRAMES
# ============================================================
clean_intl <- function(df, format_lbl) {
  if (is.null(df) || nrow(df) == 0) return(empty_cricket_table())
  
  required_cols <- c(
    "Player", "Start", "End", "Matches", "Innings", 
    "Runs", "Average", "Hundreds", "Fifties"
  )
  
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste0("Missing columns in ", format_lbl, " Cricinfo data: ", paste(missing_cols, collapse = ", ")))
  }
  
  # Tests supplied by cricketdata do not have StrikeRate; ODIs/T20Is do.
  sr_values <- if ("StrikeRate" %in% names(df)) safe_numeric(df$StrikeRate) else rep(NA_real_, nrow(df))
  
  tibble::tibble(
    Player = stringr::str_squish(as.character(df$Player)),
    Format = format_lbl,
    Matches = safe_integer(df$Matches),
    Innings = safe_integer(df$Innings),
    Runs = safe_integer(df$Runs),
    Ave = safe_numeric(df$Average),
    SR = sr_values,
    X100 = safe_integer(df$Hundreds),
    X50 = safe_integer(df$Fifties),
    Start_Year = safe_integer(df$Start),
    End_Year = safe_integer(df$End)
  )
}

# ============================================================
# 5. CLEAN CRICSHEET FRANCHISE BALL-BY-BALL (BBB) DATA
# ============================================================
clean_league_bbb <- function(df, format_lbl) {
  if (is.null(df) || nrow(df) == 0) {
    message(paste("No ball-by-ball data available for", format_lbl))
    return(empty_cricket_table())
  }
  
  message(sprintf("Processing %s ball-by-ball data: %s deliveries...", format_lbl, format(nrow(df), big.mark = ",")))
  
  required_cols <- c("match_id", "innings", "striker", "runs_off_bat")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste0("Cricsheet ", format_lbl, " data is missing columns. Available fields: ", paste(names(df), collapse = ", ")))
  }
  
  has_wides <- "wides" %in% names(df)
  has_start_date <- "start_date" %in% names(df)
  has_player_dismissed <- "player_dismissed" %in% names(df)
  
  date_values <- if (has_start_date) suppressWarnings(as.Date(df$start_date)) else rep(as.Date(NA), nrow(df))
  runs_values <- safe_numeric(df$runs_off_bat)
  valid_ball <- if (has_wides) is.na(safe_numeric(df$wides)) | safe_numeric(df$wides) == 0 else rep(TRUE, nrow(df))
  
  working_df <- df %>% mutate(.runs = runs_values, .valid_ball = valid_ball, .date = date_values)
  
  # 💎 CRITICAL FIX: Group by match_id & striker together to capture total match runs (collapsing Super Over splits)
  match_day_runs <- working_df %>%
    dplyr::group_by(match_id, striker) %>%
    dplyr::summarise(
      Runs = sum(.runs, na.rm = TRUE), 
      BallsFaced = sum(.valid_ball, na.rm = TRUE), 
      InningsCount = dplyr::n_distinct(innings), # Keep safe count of actual innings appearances
      .groups = "drop"
    )
  
  # Accumulate dismissals per match securely
  dismissed <- if (has_player_dismissed) {
    working_df %>%
      dplyr::filter(!is.na(player_dismissed), player_dismissed != "") %>%
      dplyr::distinct(match_id, player = player_dismissed) %>%
      dplyr::mutate(Dismissed = 1L)
  } else {
    tibble::tibble(match_id = character(), player = character(), Dismissed = integer())
  }
  
  match_day_runs <- match_day_runs %>%
    dplyr::left_join(dismissed, by = c("match_id", "striker" = "player")) %>%
    dplyr::mutate(Dismissed = tidyr::replace_na(Dismissed, 0L))
  
  # Player career summary base metrics
  player_summary <- match_day_runs %>%
    dplyr::group_by(striker) %>%
    dplyr::summarise(
      Matches = dplyr::n_distinct(match_id), 
      Innings = sum(InningsCount, na.rm = TRUE), 
      Runs = sum(Runs, na.rm = TRUE), 
      BallsFaced = sum(BallsFaced, na.rm = TRUE), 
      Dismissals = sum(Dismissed, na.rm = TRUE), 
      .groups = "drop"
    )
  
  # 💎 CRITICAL FIX: Milestones are now parsed accurately from total consolidated match scores!
  milestones <- match_day_runs %>%
    dplyr::group_by(striker) %>%
    dplyr::summarise(
      X100 = sum(Runs >= 100, na.rm = TRUE), 
      X50 = sum(Runs >= 50 & Runs < 100, na.rm = TRUE), 
      .groups = "drop"
    )
  
  player_summary <- player_summary %>% dplyr::left_join(milestones, by = "striker")
  
  dates_df <- if (has_start_date && !all(is.na(date_values))) {
    working_df %>%
      dplyr::filter(!is.na(.date)) %>%
      dplyr::group_by(striker) %>%
      dplyr::summarise(Start_Year = min(as.integer(format(.date, "%Y")), na.rm = TRUE),
                       End_Year = max(as.integer(format(.date, "%Y")), na.rm = TRUE), .groups = "drop")
  } else {
    tibble::tibble(striker = character(), Start_Year = integer(), End_Year = integer())
  }
  
  player_summary %>%
    dplyr::left_join(dates_df, by = "striker") %>%
    dplyr::mutate(Ave = dplyr::case_when(Dismissals > 0 ~ Runs / Dismissals, TRUE ~ as.numeric(Runs)),
                  SR = dplyr::case_when(BallsFaced > 0 ~ Runs / BallsFaced * 100, TRUE ~ NA_real_)) %>%
    dplyr::transmute(Player = stringr::str_squish(as.character(striker)), Format = format_lbl,
                     Matches = as.integer(Matches), Innings = as.integer(Innings), Runs = as.integer(Runs),
                     Ave = round(Ave, 2), SR = round(SR, 2), X100 = as.integer(X100), X50 = as.integer(X50),
                     Start_Year = as.integer(Start_Year), End_Year = as.integer(End_Year)) %>%
    dplyr::filter(!is.na(Player), Player != "")
}

# ============================================================
# 6. PIPELINE API INGESTION ORCHESTRATOR
# ============================================================
fetch_and_clean_data <- function(gender_type) {
  message(paste("\n==================================================\nSourcing Multi-Format Database:", gender_type))
  sex_param <- if (gender_type == "Male") "men" else "women"
  gender_param <- if (gender_type == "Male") "male" else "female"
  league_name <- if (gender_type == "Male") "IPL" else "WPL"
  league_slug <- if (gender_type == "Male") "ipl" else "wpl"
  
  message("Downloading Test batting statistics...")
  tests_raw <- fetch_cricinfo(matchtype = "test", sex = sex_param, activity = "batting")
  
  message("Downloading ODI batting statistics...")
  odis_raw <- fetch_cricinfo(matchtype = "odi", sex = sex_param, activity = "batting")
  
  message("Downloading T20I batting statistics...")
  t20is_raw <- fetch_cricinfo(matchtype = "t20", sex = sex_param, activity = "batting")
  
  tests_clean <- clean_intl(tests_raw, "Tests")
  odis_clean <- clean_intl(odis_raw, "ODIs")
  t20i_clean <- clean_intl(t20is_raw, "International T20")
  
  message(paste("Downloading", league_name, "ball-by-ball data..."))
  league_raw <- fetch_cricsheet(type = "bbb", gender = gender_param, competition = league_slug)
  league_clean <- clean_league_bbb(league_raw, league_name)
  
  combined_data <- dplyr::bind_rows(tests_clean, odis_clean, t20i_clean, league_clean) %>%
    dplyr::filter(!is.na(Player), Player != "", !is.na(Runs)) %>%
    dplyr::mutate(Matches = tidyr::replace_na(Matches, 0L), Innings = tidyr::replace_na(Innings, 0L),
                  Runs = tidyr::replace_na(Runs, 0L), Ave = tidyr::replace_na(Ave, 0),
                  X100 = tidyr::replace_na(X100, 0L), X50 = tidyr::replace_na(X50, 0L))
  
  target_cache <- if (gender_type == "Male") CACHE_MALE else CACHE_FEMALE
  readr::write_csv(combined_data, target_cache)
  
  message(sprintf("Database cached: %s\nRecords: %s\n==================================================", target_cache, format(nrow(combined_data), big.mark = ",")))
  return(combined_data)
}

# ============================================================
# 7. LAZY STORAGE ENGINE CACHE LOADER
# ============================================================
load_initial_data <- function(gender_type) {
  target_cache <- if (gender_type == "Male") CACHE_MALE else CACHE_FEMALE
  if (file.exists(target_cache)) {
    message(paste("Loading cached", gender_type, "database..."))
    data <- readr::read_csv(target_cache, show_col_types = FALSE)
    expected_cols <- c("Player", "Format", "Matches", "Innings", "Runs", "Ave", "SR", "X100", "X50", "Start_Year", "End_Year")
    if (length(setdiff(expected_cols, names(data))) > 0) {
      message("Cache schema outdated. Rebuilding cache...")
      return(fetch_and_clean_data(gender_type))
    }
    return(data)
  }
  fetch_and_clean_data(gender_type)
}

#Execute boot setup configuration
initial_data <- load_initial_data("Male")
