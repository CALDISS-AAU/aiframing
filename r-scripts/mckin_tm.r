library(jsonlite)
library(tm)
library(stringr)
library(tidyverse)
library(tidytext)
library(ggplot2)
library(openNLP)
library(udpipe)

data_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/data_raw/"
work_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/data_work/"
mat_path <- ""
out_path <- "D:/OneDrive/OneDrive - Aalborg Universitet/aiframing_coma_E19/output/"

filepath_mckin <- paste0(data_path, "mckin_articles.json")

mckin_texts <- fromJSON(filepath_mckin)

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
  text_clean = gsub(fill_text2, "", text_nopunct5)
  text_clean = gsub(fill_text3, "", text_nopunct5)
  return(text_clean)
}

mckin_texts_clean <- map(mckin_texts, text_cleanup)

stop_custom <- c("")
stopwords_act <- c(stopwords("english"), stop_custom)

##TOKENIZE##
text_tokenizer <- function(text, stopvec){
  text_nofill = gsub(fill_text, "", text)
  text_nopunct = removePunctuation(text_nofill)
  text_nows = stripWhitespace(text_nopunct)
  text_nopunct1 = gsub("”", "", text_nows)
  text_nopunct2 = gsub("’", "", text_nopunct1)
  text_nopunct3 = gsub("‘", "", text_nopunct2)
  text_nopunct4 = gsub("„", "", text_nopunct3)
  text_nopunct5 = gsub("“", "", text_nopunct4)
  text_clean = gsub(fill_text2, "", text_nopunct5)
  text_clean = gsub(fill_text3, "", text_nopunct5)
  text_tokens = Boost_tokenizer(text_clean)
  text_nostop = text_tokens[!(text_tokens %in% stopvec)]
  text_lenfilt = text_nostop[which(nchar(text_nostop) > 1)]
  return(text_lenfilt)
}

mckin_tokens <- map(mckin_texts, text_tokenizer, stopwords_act)

##TEXT DF##
library(dplyr)
tidy_conv <- function(wordvec, pagetitle){
  page_tidy <- dplyr::as_data_frame(wordvec) %>%
    count(value, sort = TRUE) %>%
    mutate(page_title = names(pagetitle),
           term = value, 
           count = n) %>%
    select(page_title, term, count)
}

tidy_conv_list <- function(tokenlist) {
  df_list <- list()
  for (i in 1:length(tokenlist)){
    page_df <- tidy_conv(tokenlist[[i]], tokenlist[i])
    df_list[[names(tokenlist[i])]] <- page_df
  }
  return(df_list)
}

mckin_tidy <- tidy_conv_list(mckin_tokens)

# Variables: page_title: name of article, term: word token, count: count of token in text, doccount: number of documents token appears in
mckin_tidy <- bind_rows(mckin_tidy) %>%
  group_by(term) %>%
  mutate(doccount = n()) %>%
  ungroup() %>%
  filter(doccount != length(mckin_texts))

setwd(work_path)
write_csv(mckin_tidy, "mckin_tidy.csv")

##SUMMARIES##
mckin_wordcount <- mckin_tidy %>%
  group_by(term) %>%
  summarise(wordcount = sum(count))


##ANNOTATED TEXT##
setwd(work_path)
#udmodel <- udpipe_download_model(language = "english")
udmodel_eng <- udpipe_load_model(file = paste0(work_path, "english-ewt-ud-2.4-190531.udpipe"))

mckin_annotate <- udpipe_annotate(udmodel_eng, unlist(mckin_texts_clean))
mckin_df_annotate <- data.frame(mckin_annotate)

write_csv(mckin_df_annotate, "mckin_annotated.csv")

##SUMMARIES##
library(lattice)

#NOUNS BARCHART
mckin_df_annotate %>%
  filter(upos == "NOUN") %>%
  group_by(token) %>%
  summarize(tokencount = n()) %>%
  mutate(token = reorder(token, tokencount)) %>%
  top_n(20) %>%
  arrange(desc(tokencount)) %>%
  ggplot(aes(token, tokencount)) + 
  geom_col() + 
  coord_flip() + 
  xlab(NULL) + 
  ylab("count") + 
  ggtitle("Most occuring nouns in McKinsey AI articles") + 
  theme(plot.title = element_text(hjust = 0.5)) + 
  scale_y_continuous(breaks = seq(0, 500, by = 50))

ggsave(paste0(out_path, "mckinsey_nouns_raw.png"))

#VERBS BARCHART
mckin_df_annotate %>%
  filter(upos == "VERB") %>%
  group_by(lemma) %>%
  summarize(lemmacount = n()) %>%
  mutate(lemma = reorder(lemma, lemmacount)) %>%
  top_n(20) %>%
  arrange(desc(lemmacount)) %>%
  ggplot(aes(lemma, lemmacount)) + 
  geom_col() + 
  coord_flip() + 
  xlab(NULL) + 
  ylab("count") + 
  ggtitle("Most occuring verbs in McKinsey AI articles") + 
  theme(plot.title = element_text(hjust = 0.5)) + 
  scale_y_continuous(breaks = seq(0, 300, by = 25))

ggsave(paste0(out_path, "mckinsey_verbs_raw.png"))

#ADJ BARCHART
mckin_df_annotate %>%
  filter(upos == "ADJ") %>%
  group_by(lemma) %>%
  summarize(lemmacount = n()) %>%
  mutate(lemma = reorder(lemma, lemmacount)) %>%
  top_n(20) %>%
  arrange(desc(lemmacount)) %>%
  ggplot(aes(lemma, lemmacount)) + 
  geom_col() + 
  coord_flip() + 
  xlab(NULL) + 
  ylab("count") + 
  ggtitle("Most occuring adjectives in McKinsey AI articles") + 
  theme(plot.title = element_text(hjust = 0.5)) + 
  scale_y_continuous(breaks = seq(0, 200, by = 25))

ggsave(paste0(out_path, "mckinsey_adj_raw.png"))

##BIGrAMS##
library(igraph)

mckin_df <- dplyr::as_data_frame((matrix(mckin_texts_clean))) %>%
  mutate(title = names(mckin_texts_clean),
         text = V1) %>%
  select(title, text)

mckin_df$text <- map_chr(mckin_df$text, unlist)

mckin_bigrams <- mckin_df %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2)

mckin_bigrams_filt <- mckin_bigrams %>%
  separate(bigram, c("word1", "word2"), sep = " ") %>%
  filter(!word1 %in% stopwords_act) %>%
  filter(!word2 %in% stopwords_act)

mckin_bigrams_count <- mckin_bigrams_filt %>%
  count(word1, word2, sort = TRUE)

mckin_bigrams_graph <- mckin_bigrams_count %>%
  filter(n > 5) %>%
  graph_from_data_frame()


##GGRAPH##
library(ggraph)

set.seed(42)

a <- grid::arrow(type = "closed", length = unit(.05, "inches"))

ggraph(mckin_bigrams_graph, layout = "fr") + 
  geom_edge_link(arrow = a, end_cap = circle(.07, 'inches')) + 
  geom_node_point(color = "blue", size = 1) + 
  geom_node_text(aes(label = name), vjust = 1, hjust = 1) + 
  theme_void() + 
  ggtitle("McKinsey Bigrams") +
  theme(plot.title = element_text(hjust = 0.5, colour = "darkorchid4", size = 30))

ggsave(paste0(out_path, "mckinsey_bigrams_raw.png"))

##SENTIMENT - fix graph: https://stackoverflow.com/questions/34001024/ggplot-order-bars-in-faceted-bar-chart-per-facet##
mckin_sent <- mckin_tidy %>%
  mutate(word = term,
         n = count) %>%
  select(word, n) %>%
  inner_join(get_sentiments("nrc"))

mckin_sent %>%
  filter(sentiment %in% c("positive", "negative")) %>%
  group_by(sentiment) %>%
  top_n(20, n) %>%
  arrange(desc(n)) %>%
  ggplot(aes(word, n, fill = sentiment)) +
  geom_col(show.legend = FALSE) + 
  facet_wrap(~sentiment, scales = "free_y") + 
  labs(y = "Contribution to sentiment",
       x = NULL) + 
  coord_flip()
