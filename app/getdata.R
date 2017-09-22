library(leaflet)
library(rgdal)
library(tidyr)


# import shapefiles -------------------------------------------------------


# import data from shapefile
japan <- readOGR(dsn="./data/japan_ver81", layer="japan_ver81")

# subset 23 tokyo wards 
tokyo <- subset(japan, KEN %in% "東京都")
twards <- subset(tokyo, grepl("区$", SIKUCHOSON))

# rename english ward names (delete "-ku")
twards$CITY_ENG <- gsub(pattern = "-ku", replacement = "", twards$CITY_ENG)
# retain meaningful columns
twards@data <- twards@data[,-c(3:5)]

# rename population and household columns
names(twards)[names(twards) == "P_NUM"] <- "POP_NUM"
names(twards)[names(twards) == "H_NUM"] <- "HH_NUM"

# transform to WGS84 reference system
twards84 <- spTransform(twards, CRS("+init=epsg:4326"))


# import statistics on wards ----------------------------------------------


# read in population data
tpop2010 <- read.csv("./data/001.csv", skip = 9, header = TRUE, 
                     check.names = FALSE, fileEncoding = "SHIFT-JIS")
tpop2015 <- read.csv("./data/001_13.csv", skip = 9, header = TRUE, 
                     check.names = FALSE, fileEncoding = "SHIFT-JIS") 

# read in population by gender data
tgender2010 <- read.csv("./data/002.csv", skip = 6, header = TRUE, 
                        check.names = FALSE, fileEncoding = "SHIFT-JIS")
tgender2015 <- read.csv("./data/002_13.csv", skip = 6, header = TRUE, 
                        check.names = FALSE, fileEncoding = "SHIFT-JIS")

# read in population by age data
tage2010 <- read.csv("./data/00320.csv", skip = 10, header = TRUE, 
                        check.names = FALSE, fileEncoding = "SHIFT-JIS")
tage2015 <- read.csv("./data/00320_13.csv", skip = 11, header = TRUE, 
                        check.names = FALSE, fileEncoding = "SHIFT-JIS")


# cleaning population data ------------------------------------------------


areacodes <- 13101:13123

# clean population data 2015
tpop2015_clean <- tpop2015
colnames(tpop2015_clean)[7] <- "ward"
tpop2015_clean <- tpop2015_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0) %>%
  select(3,7:8,12)

# clean population data 2010
tpop2010_clean <- tpop2010
colnames(tpop2010_clean)[7] <- "ward"
tpop2010_clean <- tpop2010_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0) %>%
  select(3,7:9)

# combine population data
tpop <- left_join(tpop2015_clean, tpop2010_clean)
colnames(tpop) <- c("JCODE", "SIKUCHOSON", "POP_2015",
                    "AREA_KM2", "POP_2010", "POP_2005")
tpop$JCODE <- as.factor(tpop$JCODE)
twards84@data <- left_join(twards84@data, tpop)


# cleaning population by gender data --------------------------------------


# clean population by gender data 2015
tgender2015_clean <- tgender2015
colnames(tgender2015_clean)[7] <- "ward"
tgender2015_clean <- tgender2015_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0) %>%
  select(3,7:10,12)
colnames(tgender2015_clean) <- c("JCODE", "SIKUCHOSON", "POP_2015",
                                 "M_2015", "F_2015", "HH_2015")

# clean population by gender data 2010
tgender2010_clean <- tgender2010
colnames(tgender2010_clean)[7] <- "ward"
tgender2010_clean <- tgender2010_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0) %>%
  select(3,7:11)
colnames(tgender2010_clean) <- c("JCODE", "SIKUCHOSON", "POP_2010",
                                 "M_2010", "F_2010", "HH_2010")

# combine population by gender data
tgender <- left_join(tgender2015_clean, tgender2010_clean)

tgender$JCODE <- as.character(tgender$JCODE)
twards84@data <- left_join(twards84@data, tgender)


# cleaning population by age data -----------------------------------------


# clean population by age data 2015
tage2015_clean <- tage2015
colnames(tage2015_clean)[2] <- "item"
colnames(tage2015_clean)[7] <- "ward"
tage2015_clean <- tage2015_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0  & item == 101) %>%
  select(3,7:8,113:138)
colnames(tage2015_clean) <- sub("（再掲）", "", colnames(tage2015_clean))
colnames(tage2015_clean) <- sub("歳", "", colnames(tage2015_clean))
colnames(tage2015_clean) <- sub("〜", "-", colnames(tage2015_clean))
colnames(tage2015_clean)[4:length(tage2015_clean)] <- sub("$", "_2015", 
  colnames(tage2015_clean)[4:length(tage2015_clean)])
colnames(tage2015_clean)[1:3] <- c("JCODE", "SIKUCHOSON", "POP_2015")

# clean population by age data 2010
tage2010_clean <- tage2010
colnames(tage2010_clean)[2] <- "item"
colnames(tage2010_clean)[7] <- "item2"
colnames(tage2010_clean)[8] <- "item3"
colnames(tage2010_clean)[9] <- "ward"
tage2010_clean <- tage2010_clean %>%
  filter(地域コード %in% areacodes & 地域識別コード==0 & item=="1" & item2=="danjo.0000") %>%
  select(3,9:10,115:140)
colnames(tage2010_clean) <- sub("（再掲）", "", colnames(tage2010_clean))
colnames(tage2010_clean) <- sub("歳", "", colnames(tage2010_clean))
colnames(tage2010_clean) <- sub("〜", "-", colnames(tage2010_clean))
colnames(tage2010_clean)[4:length(tage2010_clean)] <- sub("$", "_2010", 
  colnames(tage2010_clean)[4:length(tage2010_clean)])
colnames(tage2010_clean)[1:3] <- c("JCODE", "SIKUCHOSON", "POP_2010")

# combine population by age data
tage <- left_join(tage2015_clean, tage2010_clean)

tage$JCODE <- as.character(tage$JCODE)
twards84@data <- left_join(twards84@data, tage)

# save to Rds file 
saveRDS(object = twards84, file = "./data/twards84.Rds")