library(jsonlite)
library(tm)
library(stringr)
library(tidyverse)
library(tidytext)
library(ggplot2)
library(openNLP)
library(udpipe)

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

all_texts_clean <- c(mckin_texts_clean, ey_texts_clean, bcg_texts_clean)

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

cons_bigrams <- cons_bi_anno$bigram         

cons_anno_df <- data.frame(udpipe_annotate(udmodel_eng, unlist(all_texts_clean)))

## WORDLISTS
cons_words_df <- cons_anno_df %>%
  select(token, lemma, upos, xpos, feats, dep_rel) %>%
  distinct()

wordlists <- list()

for (wtype in unique(cons_words_df$upos)) {
  words <- cons_anno_df %>%
    filter(upos == wtype) %>%
    select(token)
  words <- list(unique(words$token))
  wordlists <- append(wordlists, words)
}
names(wordlists) <- unique(cons_words_df$upos)

## NGRAMS

cons_ngram <- cons_df %>%
  unnest_tokens(sentence, text, token = stringr::str_split, pattern = "\\.", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\?", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\:", to_lower = FALSE) %>%
  unnest_tokens(sentence, sentence, token = stringr::str_split, pattern = "\\!", to_lower = FALSE) %>%
  mutate(sent_num = 1:nrow(.)) %>%
  mutate(title = paste0(title, " - ", as.character(sent_num))) %>%
  unnest_tokens(ngrams, sentence, token = "ngrams", n = 10, to_lower = FALSE)

## CONVERTER NGRAMS TIL TOKEN-VEKTORER

## CHECK FOR BIGRAMS

# FUNCTION
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


## PRE-PROCES NGRAMS-VECTOR: tal, symboler, stopord
stop_custom <- c(wordlists$DET, wordlists$ADP, wordlists$PROPN, wordlists$AUX, wordlists$NUM, wordlists$VERB, wordlists$ADV, 
                 wordlists$PRON, wordlists$SCONJ, wordlists$CCONJ, wordlists$PART, wordlists$ADJ)
keep_words <- c(wordlists$NOUN)
stop_custom <- str_to_lower(stop_custom[!(stop_custom %in% keep_words)])
act_stop <- unique(c(stopwords("english"), stop_custom))

tokenize_proces <- function(text, stopvec, bigrams){
  text_nopunct = removePunctuation(text)
  text_nonumb = removeNumbers(text_nopunct)
  text_lenfilt = str_replace_all(text_nonumb, "\\b[[:lower:]]{1,2}(\\s|$)|\\b[[:upper:]]{1}(\\s|$)", "")
  tokens = Boost_tokenizer(text_lenfilt)
  
  tokens_lower = str_to_lower(tokens)
  
  tokens = tokens[!(str_to_lower(tokens) %in% stopvec)]
  
  tokens = bigram_insert(tokens, bigrams)

  return(tokens)
}

## TOKENIZE

cons_tokens <- cons_ngram %>%
  mutate(tokens = map(ngrams, tokenize_proces, stopvec = act_stop, bigrams = cons_bigrams))

cons_tokens$tokens <- map_chr(cons_tokens$tokens, paste, collapse = ", ")

cons_tokens <- cons_tokens %>%
  distinct(title, tokens, .keep_all = TRUE)

cons_tokens$tokens_vec <- map(str_split(cons_tokens$tokens, pattern = ", "), unlist)
cons_tokens$tokens_len <- map_dbl(cons_tokens$tokens_vec, length)
cons_tokens$firsttoken <- map_chr(cons_tokens$tokens_vec, 1)
cons_tokens$tokens_vec <- NULL

#cons_tokens_filt <- cons_tokens %>%
#  group_by(sent_num, firsttoken) %>%
#  top_n(1, tokens_len) %>%
#  ungroup() %>%
#  select(agency, title, sent_num, ngrams, tokens) %>%
#  filter(!(is.na(ngrams)))

cons_tokens_filt <- cons_tokens %>%
  select(agency, title, sent_num, ngrams, tokens) %>%
  filter(!(is.na(ngrams)))


## EDGE-LIST FORMAT? - HVORDAN GEMMES VEKTORER TIL AT BLIVE LÆST SOM LISTER I PYTHON?
cons_tokens_exp <- cons_tokens_filt %>%
  mutate(title = str_replace(title, "\\s-\\s\\d{1,5}", ""))

setwd(work_path)
#write_csv(cons_tokens, "allcons_tokens_df.csv")
#write_csv(cons_tokens_exp, "allcons_tokens_nounadj_df.csv")
write_csv(cons_tokens_exp, "allcons_tokens_noun_df.csv")

## UDLED NØGLEORD - TF-IDF?
