library(shiny)
library(shinydashboard)
library(dplyr)
library(tidyr)
library(leaflet)
library(rgdal)
library(DT)
library(ggplot2)


# Load static data
tWards <- readRDS('data/twards84.Rds')
# Find the edges of our map
bounds<-bbox(tWards)


function(input, output, session) {
  # make reactive variables
  # makeReactiveBinding("tWards")
  
  # render Map
  output$myMap<-renderLeaflet({
    leaflet() %>%
      addProviderTiles("Esri.WorldStreetMap", group = "Esri.WorldStreetMap") %>%
      addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
      addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap.Mapnik") %>%
      addProviderTiles("OpenStreetMap.BlackAndWhite", group = "OpenStreetMap.BlackAndWhite") %>%
      # Centre the map in the middle of our co-ordinates
      setView(mean(bounds[1,]),
              mean(bounds[2,]),
              zoom=11
      )
  })
  
  # add choropleth map
  observe({
    # colour palette mapped to data
    pal <- colorBin("RdYlBu", domain = tWards$POP_2015)
    
    myPopup <- paste0("<strong>",tWards$CITY_ENG,"</strong> ",
                      tWards$SIKUCHOSON,
                      "<br><strong>Population:</strong> ",
                      formatC(tWards$POP_2015, format="d", big.mark = ","),
                      "<br><strong>Male:</strong> ",
                      formatC(tWards$M_2015, format="d", big.mark = ","),
                      "<br><strong>Female:</strong> ",
                      formatC(tWards$F_2015, format="d", big.mark = ","),
                      "<br><strong>15未満:</strong> ",
                      formatC(tWards$`15未満_2015`, format="d", big.mark = ","),
                      "<br><strong>15-64:</strong> ",
                      formatC(tWards$`15-64_2015`, format="d", big.mark = ","),
                      "<br><strong>65以上:</strong> ",
                      formatC(tWards$`65以上_2015`, format="d", big.mark = ","))
    
    # If the data changes, the polygons are cleared and redrawn, however, the map (above) is not redrawn
    leafletProxy("myMap") %>%
      clearShapes() %>%
      addPolygons(data = tWards,
                  color = "#000066", opacity = 1, weight = 2, group = "Choropleth Map",
                  fillColor = ~pal(POP_2015), fillOpacity = 0.7,
                  label=~paste0(CITY_ENG, " ", SIKUCHOSON),
                  labelOptions= labelOptions(direction = 'auto', textsize="15px",
                                             padding = "3px 8px"),
                  layerId=~JCODE,
                  popup = myPopup,
                  highlightOptions = highlightOptions(color = "#666", weight = 5,
                                                      bringToFront = TRUE)) %>%
      addLegend(title = "Population Size", pal = pal, values=tWards@data$POP_2015,
                opacity = 0.6, position="bottomright", group = "Choropleth Map") %>%
      addLayersControl(baseGroups = c("Esri.WorldStreetMap",
                                      "Esri.WorldImagery",
                                      "OpenStreetMap.Mapnik",
                                      "OpenStreetMap.BlackAndWhite"),
                       overlayGroups = c("Choropleth Map"),
                       options = layersControlOptions(collapsed = TRUE, autoZIndex = FALSE))
  })
  
  # Bar plots
  sliderPopDf <- reactive({
    min <- input$sliderPop[1]
    max <- input$sliderPop[2]
    df <- isolate(tWards@data)
    subset(df, POP_2015>=min & POP_2015<=max)
  })
  
  observe({
    df <- sliderPopDf()
    if(input$drawPop == "pop"){
      output$myPlot <- renderPlot(ggplot(df, aes(reorder(CITY_ENG,-POP_2015), POP_2015/1e3)) + 
                                    geom_bar(stat="identity", fill="steelblue", width = 0.6) + 
                                    coord_flip() +
                                    labs(x = "", y = "")
      )
      
      # tWards@data %>% ggvis(~CITY_ENG, ~POP_2015/1000, fill:="#33ccff") %>% 
      #   set_options(width = "auto", resizable=FALSE) %>%
      #   layer_bars() %>% 
      #   add_axis("x", title = "", tick_padding = 30, 
      #            properties = axis_props(labels = list(angle = -90, 
      #                                                  baseline = "middle"))) %>% 
      #   add_axis("y", title = "") %>%
      #   bind_shiny("myPlot")
    } else if (input$drawPop == "gender") {
      df <- dplyr::select(df, matches("JCODE|CITY_ENG|^M_2015|^F_2015"))
      df <- gather(df, GENDER, POP, -JCODE, -CITY_ENG)
      df$GENDER <- gsub(pattern = "_2015", replacement = "", df$GENDER)
      
      output$myPlot <- renderPlot(ggplot(df, aes(reorder(CITY_ENG,-POP), POP/1e3, fill=GENDER)) + 
                                    scale_fill_manual(values = c("#c43a3d", "steelblue")) +
                                    geom_bar(stat="identity", position = position_dodge(), width = 0.8) + 
                                    coord_flip() +
                                    labs(x = "", y = "") +
                                    theme(legend.position = c(0.8, 0.9))
      )
      
      # df <- df %>% mutate(CITY_GENDER = factor(paste(CITY_ENG, GENDER)))
      # df %>%  ggvis(~CITY_GENDER, ~POP, fill=~GENDER) %>% 
      #   set_options(width = "auto", resizable=FALSE) %>%
      #   layer_bars(stack = FALSE) %>% 
      #   add_axis("x", title = "", tick_padding = 30,
      #            properties = axis_props(labels = list(angle = -90))) %>% 
      #   add_axis("y", title = "") %>%
      #   add_legend("fill", title = "Gender",
      #              properties = legend_props(labels = list(fontSize = 14, dx = 5),
      #                                        symbol = list(stroke = "black", strokeWidth = 2,
      #                                                      shape = "square", size = 200),
      #                                        legend = list(x = scaled_value("x", 1),
      #                                                      y = scaled_value("y", 450000)
      #                                                      )
      #                                        )
      #              ) %>%
      #   bind_shiny("myPlot")
      
    } else if (input$drawPop == "age") {
      df <- dplyr::select(df, matches("JCODE|CITY_ENG|^15未満_2015|^15-64_2015|^65以上_2015"))
      df <- gather(df, AGE, POP, -JCODE, -CITY_ENG)
      df$AGE <- gsub(pattern = "_2015", replacement = "", df$AGE)
      
      output$myPlot <- renderPlot(ggplot(df, aes(reorder(CITY_ENG,-POP), POP/1e3, fill=AGE)) +
                                    scale_fill_manual(values = c("steelblue", "#c43a3d", "#47892e")) +
                                    geom_bar(stat="identity", position = position_dodge(), width = 0.8) + 
                                    coord_flip() +
                                    labs(x = "", y = "") +
                                    theme(legend.position = c(0.8, 0.9))
      )
    }
  })
  # # store the click
  # observeEvent(input$myMap_shape_click,{
  #   click <- input$myMap_shape_click$id
  #   print(click)
  #   output$myPlot = renderPlot({
  #     
  #   })
  # })
  
  
  # current user geolocation
  output$lat <- renderPrint({
    input$lat
  })
  
  output$long <- renderPrint({
    input$long
  })
  
  # output$geolocation <- renderPrint({
  #   input$geolocation
  # })
}