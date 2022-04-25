library(jsonlite)
library(tm)
library(stringr)
library(tidyverse)
library(tidytext)
library(ggplot2)
library(openNLP)
library(udpipe)

# JSON TO CSV


data_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/data_raw/"
work_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/data_work/"
mat_path <- ""
out_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/output/"

filepath_mckin <- paste0(data_path, "mckin_articles.json")
filepath_ey <- paste0(data_path, "ey_articles.json")
filepath_bcg <- paste0(data_path, "bcg_articles.json")

mckin_texts <- fromJSON(filepath_mckin)
ey_texts <- fromJSON(filepath_ey)
bcg_texts <- fromJSON(filepath_bcg)

fill_text <- "our mission is to help leaders in multiple sectors develop a deeper understanding of the global economy. our flagship business publication has been defining and informing the senior-management agenda since 1964. our learning programs help organizations accelerate growth by unlocking their people's potential." 
fill_text2 <- "for the full mckinsey global institute report upon which this article is based see  tech for good using technology to smooth disruption and improve wellbeing  jacques bughin is a director of the mckinsey global institute and a senior partner in mckinseys brussels office and eric hazan is a senior partner in the paris office please sign in to print or download this article please create a profile to print or download this article create a profile to get full access to our articles and reports including those by mckinsey quarterly and the mckinsey global institute and to subscribe to our newsletters and email alerts mckinsey uses cookies to improve site functionality provide you with a better browsing experience and to enable our partners to advertise to you detailed information on the use of cookies on this site and how you can decline them is provided in our cookie policy by using this site or clicking on ok you consent to the use of cookies sign up for email alerts select topics and stay current with our latest insights"
fill_text3 <- "please sign in to print or download this article please create a profile to print or download this article create a profile to get full access to our articles and reports including those by mckinsey quarterly and the mckinsey global institute and to subscribe to our newsletters and email alerts mckinsey uses cookies to improve site functionality provide you with a better browsing experience and to enable our partners to advertise to you detailed information on the use of cookies on this site and how you can decline them is provided in our cookie policy by using this site or clicking on ok you consent to the use of cookies sign up for email alerts select topics and stay current with our latest insights"

##TEXT CLEANUP##
text_cleanup <- function(text) {
  text_nofill = gsub(fill_text, "", text)
  text_nopunct = removePunctuation(text_nofill)
  text_nows = stripWhitespace(text_nopunct)
  text_nopunct1 = gsub("”", "", text_nows)
  text_nopunct2 = gsub("’", "", text_nopunct1)
  text_nopunct3 = gsub("‘", "", text_nopunct2)
  text_nopunct4 = gsub("„", "", text_nopunct3)
  text_nopunct5 = gsub("“", "", text_nopunct4)
  text_tolower = str_to_lower(text_nopunct5)
  text_clean = gsub(fill_text2, "", text_tolower)
  text_clean = gsub(fill_text3, "", text_clean)
  return(text_clean)
}


mckin_texts_clean <- map(mckin_texts, text_cleanup)
ey_texts_clean <- map(ey_texts, text_cleanup)
bcg_texts_clean <- map(bcg_texts, text_cleanup)

texts_to_df <- function(textlist) {
  text_df = dplyr::as_data_frame((matrix(textlist))) %>%
  mutate(title = names(textlist),
         text = unlist(V1)) %>%
  select(title, text)
  return(text_df)
}

mckin_df <- texts_to_df(mckin_texts_clean)
ey_df <- texts_to_df(ey_texts_clean)
bcg_df <- texts_to_df(bcg_texts_clean)

setwd(work_path)
write_csv(mckin_df, "mckin_textdf.csv")
write_csv(ey_df, "ey_textdf.csv")
write_csv(bcg_df, "bcg_textdf.csv")