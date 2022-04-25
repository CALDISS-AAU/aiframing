#!/usr/bin/env python
# coding: utf-8

from bs4 import BeautifulSoup as bs
import requests
import re
import random
import time
from datetime import datetime as dt
import json

# defining scraper functions
def get_urls(url):
    content = requests.get(url).content
    soup = bs(content, 'html.parser')
    
    articles_soup = soup.find_all('article', class_ = 'tout--article')
        
    links_soup = [soup.find('a', class_ = 'tout__link') for soup in articles_soup]
    
    links =  [soup['href'] for soup in links_soup]
    
    return(links)

def get_pageno(url = "https://www.weforum.org/agenda/archive/fourth-industrial-revolution"):
    content = requests.get(url).content
    soup = bs(content, 'html.parser')
    
    pagitext = soup.find('div', class_ = "pagination__page-info").get_text()
    
    page_re = re.compile(r'(?<=\d/)\d{1,4}')
    
    pageno = page_re.findall(pagitext)[0]
    
    return(pageno)

def get_all_urls(url = "https://www.weforum.org/agenda/archive/fourth-industrial-revolution"):
    last_pageno = int(get_pageno(url))
    
    links = []
    
    for c, i in enumerate(range(1,last_pageno+1), start = 1):
        page_url = url + "?page=" + str(i)
        page_links = get_urls(page_url)

        links = links + page_links

        sleep_time = random.uniform(0.3, 0.6)
        time.sleep(sleep_time)
        
        print("{:.2f}% completed with {} links extracted".format(100.0 * c/last_pageno, len(links)), end = "\r")
    
    return(links)

def get_article_links(soup):
    
    links = []
    
    for s in soup.find_all('a'):
        try:
            links.append(s['href'])
        except:
            continue
    
    return(links)

def get_article_info(url):
    content = requests.get(url).content
    soup = bs(content, 'html.parser')
    
    try:
        article_soup = soup.find('div', class_ = 'article-show-container').find('div', class_ = "article-body")
    except:
        article_soup = soup.find('section', class_ = 'article-story__body')
    
    article_dict = {}
    
    article_dict['title'] = soup.title.get_text()
    article_dict['url'] = url
    article_dict['publish_date'] = soup.find(class_ = 'article-published').get_text()
    article_dict['access_date'] = str(dt.now().date())
    article_dict['links'] = get_article_links(article_soup)
    article_dict['html'] = str(article_soup)
    article_dict['text'] = article_soup.get_text()
    
    return(article_dict)

# retrieving article links and storing as txt
wef_links = get_all_urls()

with open('/../data/urls/wef_urls.txt', 'w') as f:
    for line in wef_links:
        f.write(line + "\n")

# retrieving articles based on list of links
articles = list()

for c, link in enumerate(wef_links, start = 1):
    if requests.get(link).status_code != 200:
        continue
    art_dict = get_article_info(link)
    articles.append(art_dict)
      
    print("{:.2f}% of articles downloaded".format(100.0 * c/len(wef_links)), end = '\r')
    
    sleep_time = random.uniform(0.3, 0.9)
    time.sleep(sleep_time)

# saving as json list
with open('/../data/raw/articles/wef_articles.json', 'w') as f:
    json.dump(articles, f)