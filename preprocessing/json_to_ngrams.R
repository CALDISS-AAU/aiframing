library(jsonlite)
library(tm)
library(stringr)
library(tidyverse)
library(tidytext)
library(ggplot2)
library(openNLP)
library(udpipe)

# JSON TO CSV


data_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_coma_E19/data_raw/"
work_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_coma_E19/data_work/"
mat_path <- ""
out_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_coma_E19/output/"

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
  text_nows = stripWhitespace(text_nofill)
  text_nonumb = removeNumbers(text_nows)
  text_nopunct1 = gsub("”", "", text_nonumb)
  text_nopunct2 = gsub("’", "", text_nopunct1)
  text_nopunct3 = gsub("‘", "", text_nopunct2)
  text_nopunct4 = gsub("„", "", text_nopunct3)
  text_nopunct5 = gsub("“", "", text_nopunct4)
  text_nopunct6 = gsub(",", "", text_nopunct5)
  text_clean = gsub(fill_text2, "", text_nopunct6)
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

mckin_df <- texts_to_df(mckin_texts_clean) %>%
  mutate(agency = "McKinsey")
ey_df <- texts_to_df(ey_texts_clean) %>%
  mutate(agency = "Ernst & Young")
bcg_df <- texts_to_df(bcg_texts_clean) %>%
  mutate(agency = "Boston Consulting Group")

mckin_ngram <- mckin_df %>%
  unnest_tokens(sentence, text, token = stringr::str_split, pattern = "\\.", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\?", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\:", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\!", to_lower = FALSE) %>%
  mutate(sent_num = 1:nrow(.)) %>%
  mutate(title = paste0(title, " - ", as.character(sent_num))) %>%
  unnest_tokens(ngrams, sentence, token = "ngrams", n = 10, to_lower = FALSE)
  

## FIND HYPPIGSTE BIGRAMS
stop_custom <- c("")
stopwords_act <- c(stopwords("english"), stop_custom)

text_cleanup_nostop <- function(text, stopvec){
  text_nofill = gsub(fill_text, "", text)
  text_nopunct = removePunctuation(text_nofill)
  text_nows = stripWhitespace(text_nopunct)
  text_nostop = removeWords(text_nows, stopvec)
  text_nopunct1 = gsub("”", "", text_nostop)
  text_nopunct2 = gsub("’", "", text_nopunct1)
  text_nopunct3 = gsub("‘", "", text_nopunct2)
  text_nopunct4 = gsub("„", "", text_nopunct3)
  text_nopunct5 = gsub("“", "", text_nopunct4)
  text_clean = gsub(fill_text, "", text_nopunct5)
  text_clean = gsub(fill_text2, "", text_clean)
  text_clean = gsub(fill_text3, "", text_clean)
  text_lenfilt = gsub("\\b\\w{1,2}\\s", "",text_clean)
  return(text_lenfilt)
}

mckin_texts_nostop <- map(mckin_texts, text_cleanup_nostop, stopwords_act)
mckin_nostop_df <- texts_to_df(mckin_texts_nostop) %>%
  mutate(agency = "McKinsey")

mckin_bigram <- mckin_nostop_df %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2) %>%
  group_by(bigram) %>%
  summarize(count = n())

## UDLED NØGLEORD - TF-IDF?

## CONVERTER NGRAMS TIL VEKTORER

## FILTRER NGRAMS-VECTOR UD FRA NØGLEORDSINDHOLD

## CENTRER NGRAMS-VECTOR IFT. NØGLEORD

## PRE-PROCES NGRAMS-VECTOR: tal, symboler, stopord

## EDGE-LIST FORMAT?