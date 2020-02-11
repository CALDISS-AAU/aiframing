library(jsonlite)
library(tm)
library(stringr)
library(tidyverse)
library(tidytext)
library(ggplot2)
library(openNLP)
library(udpipe)
library(lubridate)
library(dplyr)
library(feather)

location <- "work" #set "home", "laptop", "work" or "work-lap"

if (location == "home") {
  data_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/"
  work_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_work/"
  mat_path <- ""
  out_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/output/"
} else if (location == "work") {
  data_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/"
  work_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_work/"
  mat_path <- ""
  out_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/output/"
} else if (location == "work-lap") {
  data_path <- "C:/Users/kgk/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/"
  work_path <- "C:/Users/kgk/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_work/"
  mat_path <- ""
  out_path <- "C:/Users/kgk/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/output/"
} else {
  print("Specify location")
}

# JSON TO CSV
filepath_mckin <- paste0(data_path, "mckin_articles.json")
filepath_ey <- paste0(data_path, "ey_articles.json")
filepath_bcg <- paste0(data_path, "bcg_articles.json")
filepath_kpmg <- paste0(data_path, "kpmg_articles.json")

mckin_texts <- map(fromJSON(filepath_mckin), stripWhitespace)
bcg_texts <- map(fromJSON(filepath_bcg), stripWhitespace)

text_import <- function(filepath){
  data_list = list()
  texts_raw = fromJSON(filepath)
  texts_df = map_dfr(texts_raw, rbind.data.frame, stringsAsFactors = FALSE)
  texts = map(as.list(texts_df$text), stripWhitespace)
  names(texts) = texts_df$title
  
  if (texts_df$agency[1] == "KPMG") {
    texts_df$article.date = str_replace(texts_df$article.date, ".*,\\s(?=\\d)", "")
    texts_df$article.date = str_replace(texts_df$article.date, "(?<=\\d{4}).*", "")
    texts_df$article.date = dmy(texts_df$article.date)
  } else if (texts_df$agency[1] == "EY") {
    texts_df$article.date = dmy(texts_df$article.date)
  }
  
  data_list = list(texts_raw, texts_df, texts)
  names(data_list) = c('raw', 'df', 'texts')
  return(data_list)
}

kpmg_import <- text_import(filepath_kpmg)
ey_import <- text_import(filepath_ey)

alldata_df <- dplyr::union(kpmg_import$df, ey_import$df)

##TEXT CLEANUP##
mckin_fill_regex <- list(mission = "Our mission is to help .* help clients in new and exciting ways",
                         sign = "Please sign in to print .* our newsletters and email alerts",
                         cookies = "McKinsey uses cookies .* stay current with our latest insights",
                         odds = "Improving your odds of success for large scale change .* your people to accelerate and sustain the change")

ey_fill_regex <- list(read = "(\\d{1,2} minute .*? \\d{4})",
                      about = "About this article .*? EY Global .*?",
                      email = "(?<=\\.) Contact us .*? Read more\\s$",
                      related = "Related topics .*? Link copied",
                      link = "Link copied", 
                      readmore = "Read more",
                      shareview = "Share your views \\<.*\\>(?=.?Summary)",
                      joinconvo = "Logo Join the conversation")

kpmg_fill_regex <- list(powered = ".*When everything changes so quickly you need the latest financial data, in real-time, to plan successful future strategies\\. Powered Enterprise Finance delivers the financial insights for you to answer questions, such as.*solid platform for continuing evolution and progress.*"
)


punct_filt <- "”|’|‘|„|“|,"

regex_list <- c(mckin_fill_regex, ey_fill_regex, kpmg_fill_regex)

text_cleanup <- function(text, regex = regex_list, punct = "”|’|‘|„|“|,") {
  text = stripWhitespace(text)
  for (regex in regex) {
    text = str_replace_all(text, regex, "")
  }
  text_nopunct = str_replace_all(text, punct, "")
  return(text_nopunct)
}

alldata_df$text_clean <- map_chr(alldata_df$text, text_cleanup)

## FIND HYPPIGSTE BIGRAMS
stop_custom <- c("")
act_stop <- c(stopwords("english"), stop_custom)

text_preproces <- function(text, stopvec){
  text_nopunct = removePunctuation(text)
  text_lower = str_to_lower(text_nopunct)
  text_nonumb = removeNumbers(text_lower)
  text_nostop = removeWords(text_nonumb, stopvec)
  text_lenfilt = str_replace_all(text_nostop, "\\b[[:lower:]]{1,2}(\\s|$)|\\b[[:upper:]]{1}(\\s|$)", "")
  return(text_lenfilt)
}

alldata_df <- alldata_df %>%
  mutate(text_pp = text_preproces(text_clean, act_stop))

cons_bigram <- alldata_df %>%
  unnest_tokens(bigram, text_pp, token = "ngrams", n = 2) %>%
  group_by(bigram) %>%
  summarize(count = n())

top_bi <- cons_bigram %>%
  arrange(desc(count)) %>%
  top_n(50)

bigrams <- top_bi

## PRE-PROCES NGRAMS-VECTOR: tal, symboler, stopord

### BIGRAMS INSERT FUNCTION
bigram_insert <- function(tokens, bigrams) {
  tokens_lower = str_to_lower(tokens)
  i = 1
  while (i + 1 <= length(tokens)) {
    bigram = paste(tokens_lower[i], tokens_lower[i + 1], sep = " ")
    if (bigram %in% bigrams){
      tokens[i] = bigram
      tokens[i + 1] = NA
    }
    i = i + 1
  }
  tokens <- tokens[!is.na(tokens)]
  return(tokens)
}

#stop_custom <- c(wordlists$DET, wordlists$ADP, wordlists$PROPN, wordlists$AUX, wordlists$NUM, wordlists$VERB, wordlists$ADV, 
#                 wordlists$PRON, wordlists$SCONJ, wordlists$CCONJ, wordlists$PART, wordlists$ADJ)
#keep_words <- c(wordlists$NOUN)
#stop_custom <- str_to_lower(stop_custom[!(stop_custom %in% keep_words)])
stop_custom <- c("")
act_stop <- unique(c(stopwords("english"), stop_custom))

tokenize_raw_proces <- function(text){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)

  tokens = Boost_tokenizer(text_nonumb)

  return(tokens)
}

tokenize_proces <- function(text, stopvec, bigrams){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)
  text_lenfilt = str_replace_all(text_nonumb, "\\b[[:lower:]]{1,2}(\\s|$)|\\b[[:upper:]]{1}(\\s|$)", "")
  tokens = Boost_tokenizer(text_lenfilt)
  
  tokens_lower = str_to_lower(tokens)
  
  tokens_nostop = tokens_lower[!(tokens_lower %in% stopvec)]
  
  tokens_bicheck = bigram_insert(tokens_nostop, bigrams)
  
  return(tokens_bicheck)
}

## TOKENIZE

alldata_df <- alldata_df %>%
  mutate(tokens_raw = map(text_pp, tokenize_raw_proces),
         tokens = map(text_pp, tokenize_proces, stopvec = act_stop, bigrams = bigrams)
  )

alldata_df$text_length <- map_dbl(alldata_df$tokens_raw, length)


## EXPORT
alldata_df$tokens_raw <- map_chr(alldata_df$tokens_raw, paste, collapse = ", ")
alldata_df$tokens <- map_chr(alldata_df$tokens, paste, collapse = ", ")

setwd(work_path)
write_feather(alldata_df, "agency_data_20200211.feather")
write_csv(alldata_df, "agency_data_20200211.csv")