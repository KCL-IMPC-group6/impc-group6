#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)
library(dplyr)
library(ggplot2)
library(matrixStats)
library(bslib)
library(plotly)


dat_test <- read.csv("../final_clean_data.csv")
#this is definitions for later
gene_list <- unique(dat_test$gene_symbol)
parameter_list <- unique(dat_test$parameter_name) 
Gene_heatmap_choice <- unique(dat_test$gene_symbol)

#plots that get called later
plot_data <- function(data, Gene_plot_choice){
  filtered_dat_gene <- data %>%
    filter(gene_symbol == !!Gene_plot_choice)
  ggplot(filtered_dat_gene, aes(x=p_value, y=analysis_id)) +
    geom_col(fill = "grey50") + #### that^ there needs to change to input #####
  scale_y_discrete(
    breaks = data$analysis_id,
    labels = data$parameter_name)+
    labs(x= "P-value", y= "Parameter Name")+
    ggtitle(paste("Statisical Scores of Phenotype for", Gene_plot_choice, "Knockout", sep=" ", collapse=NULL))+
    geom_vline(aes(xintercept = 0.05), color = "red", linetype = "dashed", linewidth = 1)+
    annotate("text", x=0.08, y=2, label="p=0.05", angle=90, size=5, color="red")+
    #scale_fill_manual(name = "p_value"> 0.05, values = "red", "grey50") #this is a try at getting the bars that are significant to change color so it is even more obvious
    theme_minimal()
}

phenotype_stat <- function(data, Phenotype_stat_choice){
  filtered_dat_phen <- data %>%
    filter(parameter_name == !!Phenotype_stat_choice)
  ggplot(filtered_dat_phen, aes(x=p_value, y=gene_symbol, fill = gene_symbol))+ 
    geom_dotplot()
}

heatmap <- function(tdata){
  ggplot(tdata, aes(x=parameter_name, y=gene_symbol, fill = p_value))+
    geom_tile()
}

#potential code for connecting to database
#install.packages(c("DBI", "RMariaDB"))

#con <- DBI::dbConnect(
# RMariaDB::MariaDB(),
#dbname = "group6_impc_phenotype",
#host = "127.0.0.1",
#port = 3306,
#username = "root",
#password = rstudioapi::askForPassword("MySQL password")
#)

#DBI::dbListTables(con)  
#DBI::dbDisconnect(con)



# Define UI for application
ui <- page_sidebar(
  
  # Application title
  titlePanel("Group 6 Shiny Page"),
  #sidebar in collapsible panel with then inputs for each further colapsable panel
  sidebar = sidebar(
    bg = "cadetblue1",
    accordion(
      accordion_panel(
        "Graph 1 options",
        selectInput("Gene_choice",
                    "Choose Gene",
                    choices = gene_list)
      ),
      accordion_panel(
        "Graph 2 options",
        selectInput("Phenotype_choice",
                    "Choose Phenotype",
                    choices = parameter_list)
      ),
      accordion_panel(
        "Graph 3 options",
        sliderInput("P_group", 
                    "P_value Slider",
                    min = 0,
                    max = 1,
                    value = c(0,0.05)),
        selectInput("Gene_choice2",
                    "Choose Genes",
                    choices = parameter_list,
                    multiple = TRUE)
      )
    )),
  #main page portion made so graphs are collapsible
  accordion(
    accordion_panel( "Statisical Scores by Gene Knockout",
                     plotOutput("plot_data", width = "100%", height = "900px")
    ),
    accordion_panel("Mice by Selected Phenotype",
                    plotOutput("phenotype_stat", width = "100%", height = "900px")
    ),
    accordion_panel("Phenotype Scores",
                    plotOutput("heatmap", width = "100%", height = "900px")
    ),
  )
)



# Define server logic
server <- function(input, output) {
  #output plots 1&2
  output$plot_data <- renderPlot({
    req(input$Gene_choice)
    plot_data(dat_test, input$Gene_choice)})
  
  output$phenotype_stat <- renderPlot({
    req(input$Phenotype_choice)
    phenotype_stat(dat_test, input$Phenotype_choice)
    
  })
  #filter data for plot 3    
  filteredData_heat <- reactive({
    req(input$P_group, input$Gene_choice2)
    subset(dat_test, p_value >= input$P_group[1] & p_value <=input$P_group[2] & is.element(parameter_name, input$Gene_choice2))
  })
  #output plot 3
  output$heatmap <- renderPlot({
    req(filteredData_heat()) 
    heatmap(filteredData_heat())
  })
}


# Run the application 
shinyApp(ui = ui, server = server)
