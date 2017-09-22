library(shinydashboard)
library(leaflet)

header<-dashboardHeader(title="Tokyo Population Map"
                        
)

sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem("Application", tabName = "app", icon = icon("map")),
    menuItem("How to use", tabName = "howtouse", icon = icon("info")),
    menuItem("Source code", icon = icon("file-code-o"), 
             href = "https://github.com/alpenfritz/tokyopopmap/tree/master/app")
  )
)

body <- dashboardBody(
  tabItems(
    # Usage
    tabItem(tabName = "howtouse",
            includeMarkdown("howtouse.md")
    ),
    tabItem(tabName = "app",
            # for user location (print lat and long)
            tags$script('
                      $(document).ready(function () {
                      navigator.geolocation.getCurrentPosition(onSuccess, onError);
                      
                      function onError (err) {
                      Shiny.onInputChange("geolocation", false);
                      }
                      
                      function onSuccess (position) {
                      setTimeout(function () {
                      var coords = position.coords;
                      console.log(coords.latitude + ", " + coords.longitude);
                      Shiny.onInputChange("geolocation", true);
                      Shiny.onInputChange("lat", coords.latitude);
                      Shiny.onInputChange("long", coords.longitude);
                      }, 10)
                      }
                      });
            '),
            
            # Map
            column(width = 9,
                   box(width = NULL,
                       solidHeader = TRUE, 
                       leafletOutput("myMap", height=800)
                   )
            ),
            
            # Sidebar
            column(width = 3,
                   box(width=NULL, status="warning",
                       solidHeader = FALSE,
                       h4("Your current coordinates:"),
                       h5("Latitude"),
                       verbatimTextOutput("lat"),
                       h5("Longitude"),
                       verbatimTextOutput("long")
                       # verbatimTextOutput("geolocation"))
                   ),
                   box(width=NULL, status="warning",
                       solidHeader = FALSE,
                       selectInput("drawPop", label = "Choose what to draw:",
                                   choices = c("Population" = "pop",
                                               "by Gender" = "gender",
                                               "by Age" = "age"
                                   ),
                                   selected = "pop"
                       ),
                       sliderInput("sliderPop", "Pick Minimum and Maximum Values",
                                   0, 1e6, value = c(0, 1e6), step = 25e3, sep = ","
                       ),
                       plotOutput("myPlot", height = 370)
                   )
            )
    )
  )
)

dashboardPage(title = "Tokyo Population Map",
              skin = ("blue"),
              header,
              sidebar,
              body
)