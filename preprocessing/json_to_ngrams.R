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

mckin_texts <- map(fromJSON(filepath_mckin), stripWhitespace)
ey_texts <- map(fromJSON(filepath_ey), stripWhitespace)
bcg_texts <- map(fromJSON(filepath_bcg), stripWhitespace)


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
                      readmore = "Read more")

punct_filt <- "”|’|‘|„|“|,"

text_cleanup <- function(text, regex = list(), punct = "”|’|‘|„|“|,") {
  for (regex in regex) {
    text <- str_replace(text, regex, "")
  }
  text_nopunct = str_replace_all(text, punct, "")
  return(text_nopunct)
}

mckin_texts_clean <- map(mckin_texts, text_cleanup, regex = mckin_fill_regex, punct = punct_filt)
ey_texts_clean <- map(ey_texts, text_cleanup, regex = ey_fill_regex)
bcg_texts_clean <- map(bcg_texts, text_cleanup)

texts_to_df <- function(textlist) {
  text_df = as_tibble(matrix(textlist)) %>%
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

## COMBINED DF
cons_df <- union(mckin_df, ey_df) %>%
  union(bcg_df)


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

cons_pr_df <- cons_df %>%
  mutate(text = text_preproces(text, act_stop))

cons_bigram <- cons_pr_df %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2) %>%
  group_by(bigram) %>%
  summarize(count = n())

top_bi <- cons_bigram %>%
  arrange(desc(count)) %>%
  top_n(50)
top_bi


## TF-IDF
cons_bigram_tfidf <- cons_pr_df %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2) %>%
  count(title, bigram, sort = TRUE) %>%
  ungroup()

total_bigrams <- cons_bigram_tfidf %>%
  group_by(title) %>%
  summarize(total = sum(n))

cons_bigram_tfidf <- left_join(cons_bigram_tfidf, total_bigrams) %>%
  bind_tf_idf(bigram, title, n)

top_bigrams_tfidf <- cons_bigram_tfidf %>%
  group_by(bigram) %>%
  summarize(mean_tfidf = sum(tf_idf)) %>%
  arrange(mean_tfidf) %>%
  top_frac(0.0015, mean_tfidf)
  

# ANNOTATE
setwd(work_path)
#udmodel <- udpipe_download_model(language = "english")
udmodel_eng <- udpipe_load_model(file = paste0(work_path, "english-ewt-ud-2.4-190531.udpipe"))

bi_annotate <- function(bigram) {
  anno_df = data.frame(udpipe_annotate(udmodel_eng, bigram))
  pos = anno_df$upos
  return(pos)
}

cons_bi_anno <- top_bigrams_tfidf %>%
  mutate(word1 = str_extract(bigram, "^.*(?=\\s)"),
         word2 = str_extract(bigram, "(?<=\\s).*$"),
         pos = map(bigram, bi_annotate)) %>%
  unnest_wider(col = pos) %>%
  mutate(word1pos = ...1,
         word2pos = ...2) %>%
  select(everything(), -...1, -...2) %>%
  filter(word1pos == "NOUN" | word2pos == "NOUN")
         

## NGRAMS

mckin_ngram <- mckin_df %>%
  unnest_tokens(sentence, text, token = stringr::str_split, pattern = "\\.", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\?", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\:", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\!", to_lower = FALSE) %>%
  mutate(sent_num = 1:nrow(.)) %>%
  mutate(title = paste0(title, " - ", as.character(sent_num))) %>%
  unnest_tokens(ngrams, sentence, token = "ngrams", n = 10, to_lower = FALSE)

## UDLED NØGLEORD - TF-IDF?

## CONVERTER NGRAMS TIL VEKTORER

## FILTRER NGRAMS-VECTOR UD FRA NØGLEORDSINDHOLD

## CENTRER NGRAMS-VECTOR IFT. NØGLEORD

## PRE-PROCES NGRAMS-VECTOR: tal, symboler, stopord

## EDGE-LIST FORMAT?