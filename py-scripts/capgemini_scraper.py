#!/usr/bin/env python
# coding: utf-8


import requests
import time
import re
from bs4 import BeautifulSoup as bs
import os
from datetime import datetime
import json
import random


SEARCH_URL_FORMAT = "https://www.capgemini.com/?s={}" # searchterm
SEARCH_RESULT_PAGE_FORMAT = "https://www.capgemini.com/page/{}/?s={}" # pageno, searchterm

data_path = os.path.join('..', '..', 'data', 'raw', 'articles')

if not os.path.isdir(data_path):
    os.mkdir(data_path)

def get_page(url):
    """
    Returns URL content. 3 retries.
    """
    
    i = 3
    while i > 0: # error handling for status 504 (gateway timeout) - 3 retries
        try:
            r = requests.get(url, timeout=5.0)
            break
        except:
            i = i - 1
            time_int = random.uniform(0.1, 0.2) 
            time.sleep(time_int)
            continue
    
    if i > 0:
        if r.status_code == 200:
            r.encoding = 'utf-8'
            text = r.text
            return(text)
        else:
            return
    else:
        return
    
    

def get_last_pageno(soup):
    """
    Returns the last page number of search results.
    """
    last_page = soup.find('a', class_ = "next page-numbers").previous_sibling.previous_sibling.get_text()
    
    return(int(last_page))


def get_result_info(itemsoup): # div.search_results__list--item
    class_suffixes = ['type', 'title', 'date', 'author', 'text', 'link']
    
    result_info = {}
    for class_suffix in class_suffixes:
        dictkey = class_suffix
        
        if class_suffix == 'date':
            try:
                dictvalue = itemsoup.find(class_ = 'card_default__{}'.format(class_suffix)).find('p').get_text(strip = True)
            except:
                dictvalue = ""
        elif class_suffix == 'link':
            try:
                dictvalue = itemsoup.find('div', class_ = 'card_default__links').find('a')['href']
            except:
                dictvalue = ""
        else:
            try:
                dictvalue = itemsoup.find(class_ = 'card_default__{}'.format(class_suffix)).get_text(strip = True)
            except:
                dictvalue = ""

        result_info[dictkey] = dictvalue
    
    return(result_info)


def get_results_souplist(soup):
    results_souplist = soup.find_all('div', class_ = 'search_results__list--item')
    
    return(results_souplist)


def get_results_info(url):
    pagesource = get_page(url)
    
    results_info = list()
    
    if pagesource is None:
        raise ValueError('No page source to parse. Check if request was succesful.')
                
    pagesoup = bs(pagesource, 'html.parser')   
    results = get_results_souplist(pagesoup)
    
    for result in results:
        result_info = get_result_info(result)
        results_info.append(result_info)
        
    return(results_info)


def get_article_info(url):
    article_info = {}
    
    article_source = get_page(url)
    
    if article_source is None:
        article_info['article links'] = ""
        article_info['article html'] = ""
        article_info['article accessed'] = 0
        article_info['article retrieval date'] = str(datetime.now().date())
    else:
        article_soup = bs(article_source, 'html.parser')
        
        article_a = article_soup.find_all('a')
        links_list = list()
        for a in article_a:
            try:
                links_list.append(a['href'])
            except KeyError:
                continue
        
        article_info['article links'] = links_list
        article_info['article html'] = article_source
        article_info['article accessed'] = 1
        article_info['article retrieval date'] = str(datetime.now().date())

    return(article_info)
    

search_term = 'artificial+intelligence'
search_url = SEARCH_URL_FORMAT.format(search_term)

result_page = get_page(search_url)
result_page_soup = bs(result_page, 'html.parser')

if result_page is None:
    raise ValueError('No page source to parse. Check if request was succesful.')

no_results_text = result_page_soup.find('div', class_ = 'pagination_current_page').get_text(strip = True)
no_results_re = re.compile("\d{1,4}(?=\t*results)")

no_results = no_results_re.findall(no_results_text)[0]
    
last_page = get_last_pageno(result_page_soup)

search_results = list()

for pageno in range(1, last_page + 1):
    print("Retrieving page {}/{}".format(pageno, last_page), end = "\r")
    results_page = SEARCH_RESULT_PAGE_FORMAT.format(pageno, search_term)
    results = get_results_info(results_page)
    
    search_results = search_results + results
    
    sleep_time = random.uniform(0.5, 1.0)
    time.sleep(sleep_time)

print(f"Retrieved {len(search_results)} out of {no_results} results")


for c, result in enumerate(search_results, start = 1):
    article_info = get_article_info(result['link'])
    
    result.update(article_info)
    
    sleep_time = random.uniform(0.5, 1.0)
    time.sleep(sleep_time)
    
    print("{:.2f}% of results retrieved".format(100.0*c/len(search_results)), end = "\r")
    
filename = 'capgemini_articles_{}.json'.format(str(datetime.now().date()))
filepath = os.path.join(data_path, filename)

with open(filepath, 'w', encoding = 'utf-8') as f:
    json.dump(search_results, f)
