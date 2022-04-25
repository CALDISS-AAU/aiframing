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

location <- "home" #set "home", "laptop", "work" or "work-lap"

if (location == "home") {
  data_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/articles/"
  work_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_work/"
  mat_path <- ""
  out_path <- "D:/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/output/"
} else if (location == "work") {
  data_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/articles/"
  work_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_work/"
  mat_path <- ""
  out_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/output/"
} else if (location == "work-lap") {
  data_path <- "C:/Users/kgk/OneDrive - Aalborg Universitet/CALDISS_projects/aiframing_cim_E19-F20/data_raw/articles/"
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
filepath_bain <- paste0(data_path, "bain_articles.json")
filepath_pwc <- paste0(data_path, "pwc_articles.json")
filepath_acc <- paste0(data_path, "accenture_articles.json")
filepath_cap <- paste0(data_path, "capgemini_articles.json")

null_to_na <- function(a_list) {
  for (i in 1:length(a_list)) {
    if (is.null(a_list[[i]])) {
      a_list[[i]] = NA
    }
  }
  return(a_list)
}

text_import <- function(filepath){
  data_list = list()
  texts_raw = fromJSON(filepath)
  texts_raw = map(texts_raw, null_to_na)
  texts_df = map_dfr(texts_raw, rbind.data.frame, stringsAsFactors = FALSE)
  texts = map(as.list(texts_df$text), stripWhitespace)
  names(texts) = texts_df$title
  
  if (texts_df$agency[1] == "KPMG") {
    texts_df$article.date = str_replace(texts_df$article.date, ".*,\\s(?=\\d)", "")
    texts_df$article.date = str_replace(texts_df$article.date, "(?<=\\d{4}).*", "")
    texts_df$article.date = dmy(texts_df$article.date)
  } else if (texts_df$agency[1] == "EY") {
    texts_df$article.date = dmy(texts_df$article.date)
  } else if (texts_df$agency[1] == "Bain & Company") {
    texts_df$article.date = ymd(floor_date(ymd_hms(texts_df$article.date), unit = "days"))
    texts_df$modified.date = ymd(floor_date(ymd_hms(texts_df$modified.date), unit = "days"))
  } else if (texts_df$agency[1] == "McKinsey") {
    texts_df$article.date = mdy(texts_df$article.date)
  } else if (texts_df$agency[1] == "PwC") {
    texts_df$article.date = ymd(floor_date(ymd_hms(texts_df$article.date), unit = "days"))
  } else if (texts_df$agency[1] == "BCG") {
    texts_df$article.date = mdy(texts_df$article.date)
  } else if (texts_df$agency[1] == "Accenture") {
    texts_df$article.date = ymd(texts_df$article.date)
  } else if (texts_df$agency[1] == "Capgemini") {
    texts_df$article.date = ymd(texts_df$article.date)
  }
  
  data_list = list(texts_raw, texts_df, texts)
  names(data_list) = c('raw', 'df', 'texts')
  return(data_list)
}

kpmg_import <- text_import(filepath_kpmg)
ey_import <- text_import(filepath_ey)
bain_import <- text_import(filepath_bain)
mckin_import <- text_import(filepath_mckin)
bcg_import <- text_import(filepath_bcg)
pwc_import <- text_import(filepath_pwc)
acc_import <- text_import(filepath_acc)
cap_import <- text_import(filepath_cap)

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

kpmg_fill_regex <- list(powered = ".*When everything changes so quickly you need the latest financial data, in real-time, to plan successful future strategies\\. Powered Enterprise Finance delivers the financial insights for you to answer questions, such as.*solid platform for continuing evolution and progress.*")

bain_fill_regex <- list(glance = "At a Glance",
                        appear = "This article originally appeared on the .*? (?=\\.)")

pwc_fill_regex <- list(functions = "if\\(.*\\).*\\{.*",
                       functions2 = "\\.[a-z]+\\-[a-z]+\\s\\..*")

punct_filt <- "”|’|‘|„|“|,"

regex_list <- c(mckin_fill_regex, ey_fill_regex, kpmg_fill_regex, bain_fill_regex, pwc_fill_regex)

#text_cleanup <- function(text, regex = regex_list, punct = "”|’|‘|„|“|,") {
#  text = stripWhitespace(text)
#  for (regex in regex) {
#    text = str_replace_all(text, regex, "")
#  }
#  text_nopunct = str_replace_all(text, punct, "")
#  return(text_nopunct)
#}

text_cleanup <- function(import, punct = "”|’|‘|„|“|,", regex = list()) {
  df = import$df
  text = stripWhitespace(df$text)
  agency = df$agency[1]
  
  if (agency == "KPMG") {
    regex = kpmg_fill_regex
  } else if (agency == "EY") {
    regex = ey_fill_regex
  } else if (agency == "Bain & Company") {
    regex = bain_fill_regex
  } else if (agency == "McKinsey") {
    regex = mckin_fill_regex
  } else if (agency == "PwC") {
    regex = pwc_fill_regex
  }
  
  for (regex in regex) {
    text = str_replace_all(text, regex, "")
  }
  
  text_nopunct = str_replace_all(text, punct, "")
  
  df$text_clean = text_nopunct
  
  import$df = df
  
  return(import)
}

kpmg_import_clean <- text_cleanup(kpmg_import)
ey_import_clean <- text_cleanup(ey_import)
bain_import_clean <- text_cleanup(bain_import)
mckin_import_clean <- text_cleanup(mckin_import)
bcg_import_clean <- text_cleanup(bcg_import)
pwc_import_clean <- text_cleanup(pwc_import)
acc_import_clean <- text_cleanup(acc_import)
cap_import_clean <- text_cleanup(cap_import)

alldata_df <- dplyr::union_all(kpmg_import_clean$df, ey_import_clean$df) %>%
  dplyr::union_all(bain_import_clean$df) %>%
  dplyr::union_all(mckin_import_clean$df) %>%
  dplyr::union_all(bcg_import_clean$df) %>%
  dplyr::union_all(pwc_import_clean$df) %>%
  dplyr::union_all(acc_import_clean$df) %>%
  dplyr::union_all(cap_import_clean$df)

## FIND HYPPIGSTE BIGRAMS
stop_custom <- c("")
act_stop <- c(stopwords("english"), stop_custom)

text_bi_preprocess <- function(text, stopvec){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)
  text_lenfilt = str_replace_all(text_nonumb, "\\b[[:lower:]]{1,2}(\\s|$)|\\b[[:upper:]]{1}(\\s|$)", "")
  text_lower = str_to_lower(text_lenfilt)
  text_nostop = removeWords(text_lower, stopvec)
  return(text_nostop)
}

cons_bigram <- alldata_df %>%
  mutate(text_bi_pp = text_bi_preprocess(text_clean, act_stop))

cons_bigram <- cons_bigram %>%
  unnest_tokens(bigram, text_bi_pp, token = "ngrams", n = 2) %>%
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

text_preprocess <- function(text, stopvec){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)
  text_lenfilt = str_replace_all(text_nonumb, "\\b[[:lower:]]{1,2}(\\s|$)|\\b[[:upper:]]{1}(\\s|$)", "")
  text_lower = str_to_lower(text_lenfilt)
  text_nostop = removeWords(text_lower, stopvec)
  return(text_nostop)
}

tokenize_raw_proces <- function(text){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)

  tokens = Boost_tokenizer(text_nonumb)

  return(tokens)
}

tokenize_proces <- function(text, bigrams){
  tokens = Boost_tokenizer(text)
  tokens_bicheck = bigram_insert(tokens, bigrams)
  
  return(tokens_bicheck)
}

## TOKENIZE

alldata_df <- alldata_df %>%
  mutate(text_pp = map_chr(text_clean, text_preprocess, stopvec = act_stop),
         tokens_raw = map(text_clean, tokenize_raw_proces)
         ) %>%
  mutate(tokens = map(text_pp, tokenize_proces, bigrams = bigrams)
  )

alldata_df$text_length <- map_dbl(alldata_df$tokens_raw, length)


## EXPORT
alldata_df$tokens_raw <- map_chr(alldata_df$tokens_raw, paste, collapse = ", ")
alldata_df$tokens <- map_chr(alldata_df$tokens, paste, collapse = ", ")

setwd(work_path)
write_feather(alldata_df, "agency_data_20200311.feather")
write_csv(alldata_df, "agency_data_20200311.csv")