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

filepath_ey <- paste0(data_path, "ey_articles.json")

ey_texts <- fromJSON(filepath_ey)

fill_text <- "our mission is to help leaders in multiple sectors develop a deeper understanding of the global economy. our flagship business publication has been defining and informing the senior-management agenda since 1964. our learning programs help organizations accelerate growth by unlocking their people's potential." 
fill_text2 <- "for the full eysey global institute report upon which this article is based see  tech for good using technology to smooth disruption and improve wellbeing  jacques bughin is a director of the eysey global institute and a senior partner in eyseys brussels office and eric hazan is a senior partner in the paris office please sign in to print or download this article please create a profile to print or download this article create a profile to get full access to our articles and reports including those by eysey quarterly and the eysey global institute and to subscribe to our newsletters and email alerts eysey uses cookies to improve site functionality provide you with a better browsing experience and to enable our partners to advertise to you detailed information on the use of cookies on this site and how you can decline them is provided in our cookie policy by using this site or clicking on ok you consent to the use of cookies sign up for email alerts select topics and stay current with our latest insights"
fill_text3 <- "please sign in to print or download this article please create a profile to print or download this article create a profile to get full access to our articles and reports including those by eysey quarterly and the eysey global institute and to subscribe to our newsletters and email alerts eysey uses cookies to improve site functionality provide you with a better browsing experience and to enable our partners to advertise to you detailed information on the use of cookies on this site and how you can decline them is provided in our cookie policy by using this site or clicking on ok you consent to the use of cookies sign up for email alerts select topics and stay current with our latest insights"

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

ey_texts_clean <- map(ey_texts, text_cleanup)

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

ey_tokens <- map(ey_texts, text_tokenizer, stopwords_act)

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

ey_tidy <- tidy_conv_list(ey_tokens)

# Variables: page_title: name of article, term: word token, count: count of token in text, doccount: number of documents token appears in
ey_tidy <- bind_rows(ey_tidy) %>%
  group_by(term) %>%
  mutate(doccount = n()) %>%
  ungroup() %>%
  filter(doccount != length(ey_texts))

setwd(work_path)
write_csv(ey_tidy, "ey_tidy.csv")

##SUMMARIES##
ey_wordcount <- ey_tidy %>%
  group_by(term) %>%
  summarise(wordcount = sum(count))


##ANNOTATED TEXT##
setwd(work_path)
#udmodel <- udpipe_download_model(language = "english")
udmodel_eng <- udpipe_load_model(file = paste0(work_path, "english-ewt-ud-2.4-190531.udpipe"))

ey_annotate <- udpipe_annotate(udmodel_eng, unlist(ey_texts_clean))
ey_df_annotate <- data.frame(ey_annotate)

write_csv(ey_df_annotate, "ey_annotated.csv")