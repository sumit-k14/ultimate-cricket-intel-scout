library(shiny)
library(bslib)
library(plotly)
library(DT)

ui <- fluidPage(
  # Classic Custom Theme Settings
  theme = bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#1b365d",      # Deep Navy Blue
    secondary = "#4a5568",    # Slate Grey
    success = "#2f855a",      # Classic Green
    base_font = bslib::font_google("Inter") # Clean corporate typography
  ),
  
  # Custom CSS inject to resolve style issues directly without separate files
  tags$head(
    tags$style(HTML("
      .navbar-brand { font-weight: bold; color: #1b365d !important; }
      .btn-warning { background-color: #2b6cb0 !important; border-color: #2b6cb0 !important; color: white !important; }
      .btn-warning:hover { background-color: #2c5282 !important; }
      .well { background-color: #f7fafc !important; border: 1px solid #e2e8f0 !important; box-shadow: none !important; }
      h5 { color: #2d3748; margin-top: 15px; margin-bottom: 10px; border-bottom: 2px solid #e2e8f0; padding-bottom: 5px; }
      
      /* Dropdown styling */
      .selectize-dropdown, .selectize-dropdown-content { background-color: #ffffff !important; }
      .selectize-dropdown .option { background-color: #ffffff !important; color: #2d3748 !important; }
      .selectize-dropdown .active { background-color: #1b365d !important; color: #ffffff !important; }
      
      /* DataTables Pagination styling */
      .page-item.active .page-link { background-color: #1b365d !important; border-color: #1b365d !important; color: white !important; }
      .page-link { color: #1b365d !important; background-color: #ffffff !important; border: 1px solid #e2e8f0 !important; }
      .page-link:hover { background-color: #edf2f7 !important; color: #1a365d !important; }
      
      /* Premium padding for the tab card panels */
      .card-body { padding: 20px !important; }
      
      /* 💎 PREMIUM HERO BANNER CSS OVERRIDES */
      .custom-hero-banner {
        background: linear-gradient(135deg, #1b365d 0%, #2a4365 100%) !important;
        border-radius: 12px !important;
        padding: 24px 30px !important;
        margin-top: 15px !important;
        margin-bottom: 25px !important;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06) !important;
        border-left: 6px solid #b7791f !important; /* Elegant gold strip matching Test format color accent */
      }
      .custom-banner-title {
        color: #ffffff !important;
        font-weight: 800 !important;
        font-size: 26px !important;
        letter-spacing: -0.5px !important;
        margin: 0 !important;
      }
      .custom-banner-subtitle {
        color: #cbd5e0 !important;
        font-size: 13px !important;
        margin-top: 6px !important;
        margin-bottom: 0 !important;
        font-weight: 400 !important;
      }
    "))
  ),
  
  # 🚀 💎 PREMIUM HERO BANNER INJECTION: Replaced default plain text titlePanel
  tags$div(
    class = "custom-hero-banner",
    tags$h2(class = "custom-banner-title", "🏏 The Ultimate All-Format Cricket Intel Scout"),
    tags$p(class = "custom-banner-subtitle", "Advanced Player Performance Diagnostics & Recruitment Pipeline Analytics Dashboard")
  ),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(inputId = "gender", label = "Select Category:", choices = c("Male", "Female"), selected = "Male"),
      selectizeInput(inputId = "players", label = "Select Players to Compare:", choices = NULL, selected = NULL,
                     multiple = TRUE, options = list(placeholder = "Type player name...", maxItems = 6)),
      radioButtons(inputId = "format_filter", label = "Match Format Scope:",
                   choices = c("All Formats", "Tests", "ODIs", "International T20", "IPL"), selected = "All Formats"),
      sliderInput(inputId = "run_range", label = "Minimum Career Runs:", min = 0, max = 20000, value = 1000, step = 200),
      hr(),
      actionButton(inputId = "refresh_btn", label = "Sync Live Repositories", icon = icon("sync"), class = "btn-warning btn-block"),
      br(), br(),
      helpText("Refresh downloads fresh Cricinfo statistics and recalculates IPL/WPL statistics."),
      width = 3
    ),
    
    mainPanel(
      navset_card_pill(
        nav_panel(
          title = "Impact Matrix", 
          icon = icon("chart-line"),
          tags$h5(tags$b("Impact Matrix: Runs vs Strike Rate")),
          plotlyOutput("runs_vs_sr", height = "500px")
        ),
        
        nav_panel(
          title = "Batting Average", 
          icon = icon("chart-bar"),
          tags$h5(tags$b("Batting Average Comparison")),
          plotlyOutput("ave_comparison", height = "500px")
        ),
        
        nav_panel(
          title = "Milestones", 
          icon = icon("trophy"),
          tags$h5(tags$b("Milestone Distribution")),
          plotlyOutput("milestones_bar", height = "500px")
        ),
        
        nav_panel(
          title = "Career Span", 
          icon = icon("history"),
          tags$h5(tags$b("Career Longevity Tracker")),
          plotlyOutput("longevity_plot", height = "500px")
        ),
        
        nav_panel(
          title = "Scorecard Table", 
          icon = icon("table"),
          tags$br(),
          DTOutput("scout_table")
        )
      ),
      width = 9
    )
  )
)
