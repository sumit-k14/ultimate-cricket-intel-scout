server <- function(input, output, session) {
  
  # Master reactive dataset
  master_data_rv <- reactiveVal(initial_data)
  
  # Fast Search & Selection Synchronization
  observeEvent(master_data_rv(), {
    current_data <- master_data_rv()
    req(current_data, nrow(current_data) > 0)
    
    all_players <- sort(unique(current_data$Player))
    current_selection <- isolate(input$players)
    valid_selection <- intersect(current_selection, all_players)
    
    if (length(valid_selection) == 0) {
      defaults <- if (input$gender == "Male") {
        c("SR Tendulkar", "V Kohli", "MS Dhoni", "RG Sharma")
      } else {
        c("S Mandhana", "Smriti Mandhana", "M Lanning", "H Kaur", "Harmanpreet Kaur")
      }
      valid_selection <- intersect(defaults, all_players)
    }
    
    updateSelectizeInput(session, "players", choices = all_players, selected = valid_selection, server = TRUE)
  }, ignoreInit = FALSE)
  
  # Category Change Pipeline (Male / Female Selection)
  observeEvent(input$gender, {
    showModal(modalDialog(
      title = "Loading Cricket Database",
      tags$p("Loading cached data or downloading fresh records... Please wait."),
      easyClose = FALSE, footer = NULL
    ))
    
    tryCatch({
      loaded_df <- load_initial_data(input$gender)
      master_data_rv(loaded_df)
      
      max_runs <- if (input$gender == "Male") 20000 else 10000
      default_runs <- if (input$gender == "Male") 1000 else 400
      step_val <- if (input$gender == "Male") 200 else 100
      
      updateSliderInput(session, "run_range", min = 0, max = max_runs, value = default_runs, step = step_val)
      
      league_lbl <- if (input$gender == "Male") "IPL" else "WPL"
      updateRadioButtons(session, "format_filter", selected = "All Formats",
                         choices = c("All Formats", "Tests", "ODIs", "International T20", league_lbl))
    }, error = function(e) {
      showNotification(paste("Loading error:", e$message), type = "error", duration = 15)
    }, finally = {
      removeModal()
    })
  }, ignoreInit = TRUE)
  
  # Manual Force Repository Sync Route
  observeEvent(input$refresh_btn, {
    showModal(modalDialog(
      title = "Comprehensive Cricket Database Sync",
      tags$p(paste("Downloading Tests, ODIs, T20Is and", if (input$gender == "Male") "IPL" else "WPL", "data.")),
      tags$p("The ball-by-ball download may take several minutes."),
      easyClose = FALSE, footer = NULL
    ))
    
    tryCatch({
      fresh_df <- fetch_and_clean_data(input$gender)
      master_data_rv(fresh_df)
      showNotification("All formats synced successfully.", type = "message", duration = 5)
    }, error = function(e) {
      showNotification(paste("Sync Error:", e$message), type = "error", duration = 15)
    }, finally = {
      removeModal()
    })
  })
  
  # Data Filtering Rules
  filtered_data <- reactive({
    data <- master_data_rv()
    req(data, nrow(data) > 0, input$run_range)
    
    data <- data %>% dplyr::filter(Runs >= input$run_range)
    if (!is.null(input$format_filter) && input$format_filter != "All Formats") {
      data <- data %>% dplyr::filter(Format == input$format_filter)
    }
    data
  })
  
  selected_players_data <- reactive({
    req(input$players, length(input$players) > 0)
    filtered_data() %>% dplyr::filter(Player %in% input$players)
  })
  
  # Output Render Interactive Plotly Visualizations
  
  output$runs_vs_sr <- renderPlotly({
    plot_data <- filtered_data() %>% dplyr::filter(!is.na(SR), is.finite(SR))
    selected_plot <- selected_players_data() %>% dplyr::filter(!is.na(SR), is.finite(SR))
    
    p <- ggplot(plot_data, aes(x = Runs, y = SR)) +
      # 💎 FIX 1: Explicitly assigned text = NULL to turn off background gray point hover events completely
      geom_point(aes(text = NULL), alpha = 0.12, color = "#cbd5e0") + 
      # 💎 FIX 2: Restored Runs and SR values into the custom tooltip string
      geom_point(data = selected_plot, 
                 aes(color = Player, 
                     text = paste0("Player: ", Player, "<br>",
                                   "Format: ", Format, "<br>",
                                   "Total Runs: ", Runs, "<br>",
                                   "Strike Rate: ", round(SR, 2))), 
                 size = 3.5) + 
      labs(x = "Total Runs", y = "Strike Rate") +
      scale_color_brewer(palette = "Dark2") + 
      theme_minimal()
    
    ggplotly(p, tooltip = "text") %>% 
      style(hoverinfo = "text") %>% 
      config(displayModeBar = "hover")
  })
  
  output$ave_comparison <- renderPlotly({
    data <- selected_players_data()
    req(nrow(data) > 0)
    
    # 💎 FIX 3: Wrapped the Ave variable inside round(..., 2) to lock tooltip formatting limits
    p <- ggplot(data, aes(x = reorder(Player, Ave), y = Ave, fill = Format, 
                          text = paste0("Player: ", Player, "<br>",
                                        "Format: ", Format, "<br>",
                                        "Average: ", round(Ave, 2)))) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      coord_flip() + 
      labs(x = NULL, y = "Runs per Dismissal") +
      scale_fill_manual(values = c(
        "Tests" = "#b7791f",             
        "ODIs" = "#2b6cb0",              
        "International T20" = "#4a5568", 
        "IPL" = "#2f855a",               
        "WPL" = "#2f855a"
      )) + 
      theme_minimal()
    
    ggplotly(p, tooltip = "text") %>% 
      style(hoverlabel = list(font = list(color = "#ffffff"))) %>% 
      config(displayModeBar = "hover")
  })
  
  output$milestones_bar <- renderPlotly({
    data <- selected_players_data()
    req(nrow(data) > 0)
    
    plot_data <- data %>%
      dplyr::select(Player, Format, X100, X50) %>%
      tidyr::pivot_longer(cols = c(X100, X50), names_to = "Milestone", values_to = "Count") %>%
      dplyr::mutate(Milestone = dplyr::case_when(Milestone == "X100" ~ "100s", Milestone == "X50" ~ "50s", TRUE ~ Milestone))
    
    p <- ggplot(plot_data, aes(x = Player, y = Count, fill = Milestone, text = paste("Player:", Player, "<br>Milestone:", Milestone, "<br>Count:", Count))) +
      geom_col(position = "stack", width = 0.65) + facet_wrap(~ Format, scales = "free_y") +
      labs(x = NULL, y = "Count") +
      scale_fill_manual(values = c("100s" = "#2b6cb0", "50s" = "#bee3f8")) +
      theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(p, tooltip = "text") %>% 
      config(displayModeBar = "hover")
  })
  
  output$longevity_plot <- renderPlotly({
    data <- selected_players_data()
    req(nrow(data) > 0)
    
    data <- data %>%
      dplyr::mutate(CareerSpan = dplyr::case_when(!is.na(Start_Year) & !is.na(End_Year) ~ End_Year - Start_Year + 1, TRUE ~ NA_real_)) %>%
      dplyr::filter(!is.na(CareerSpan), CareerSpan > 0)
    req(nrow(data) > 0)
    
    p <- ggplot(data, aes(x = Player, y = CareerSpan, fill = Player, text = paste("Player:", Player, "<br>Years Active:", CareerSpan))) +
      geom_col(width = 0.55) + facet_wrap(~ Format, scales = "free_y") +
      labs(x = NULL, y = "Years Active") +
      scale_fill_brewer(palette = "Dark2") + 
      theme_minimal() + theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(p, tooltip = "text") %>% 
      config(displayModeBar = "hover")
  })
  
  output$scout_table <- renderDT({
    filtered_data() %>%
      dplyr::select(Player, Format, Matches, Innings, Runs, Ave, SR, X100, X50) %>%
      dplyr::arrange(dplyr::desc(Runs)) %>%
      DT::datatable(
        options = list(pageLength = 15, searchHighlight = TRUE, scrollX = TRUE),
        filter = "top", rownames = FALSE,
        colnames = c("Player", "Format", "Matches", "Innings", "Runs", "Average", "Strike Rate", "100s", "50s")
      ) %>%
      DT::formatRound(columns = c("Ave", "SR"), digits = 2)
  })
}
