##########################################################################################################################################
##	Import Modules
##########################################################################################################################################
from sklearn.datasets import fetch_20newsgroups
import pandas as pd 
import numpy as np
import re
import os
import sys

##########################################################################################################################################
##	Get the Newsgroup20 data set
##########################################################################################################################################

# Get the training and testing set from the sklearn.datasets module. 
newsgroups_train = fetch_20newsgroups(subset='train')
newsgroups_test = fetch_20newsgroups(subset='test')

# Description of the data set.
## newsgroups_train.target: labels 1-20 as integers. 
## newsgroups_train.target_names: labels names. 
## newsgroups_train.data: the text. It includes a title and a body. 
## e.g. print(newsgroups_train.data[5954])

##########################################################################################################################################
##	Preprocess the newsgroups data sets. 
##########################################################################################################################################

# Function that extracts the Subject from the text, remove leading and ending white spaces and the "\n". 
# The data set is returned as a Pandas dataframe.

def preprocess_newsgroups(data):
    # Extract the Subject from each news as a separate variable. 
    def get_subject(s):
        m = re.search('Subject:(.+?)\n', s)
        if m: 
            return m.group(1).strip()
        else:
            return ''
    subject_list = [get_subject(s) for s in data.data] 

    # Keep only the text body and replace "\n" and "\t" with space, remove leading and ending white spaces as well as multiple spacing. 
    # The text body starts after the row with "NNTP-Posting-Host..." if it exists, and after the row with "Lines..." otherwise.
    def get_body(s):
        if s.find('NNTP-Posting-Host:') != -1: 
            nntp = re.search('NNTP-Posting-Host:(.+?)\n', s).group(0)
            start = s.find(nntp) + len(nntp)
        elif s.find('Lines:') != -1: 
            lines = re.search('Lines:(.+?)\n', s).group(0)
            start = s.find(lines) + len(lines)
        else:
            start = 0
        body = s[start:]
        return ' '.join(body.replace("\n", " ").replace("\t", " ").split())
    body_list = [get_body(s) for s in data.data] 

    # Create a pandas dataframe. 
    Preprocessed_df = pd.DataFrame({'Label': data.target,
                                    'Subject': subject_list,
                                    'Text': body_list})

    # Remove rows with empty text body. 
    Preprocessed_df['Text'].replace('', np.nan, inplace = True)
    Preprocessed_df.dropna(subset = ['Text'], inplace = True)

    return(Preprocessed_df)

# Apply the preprocessing to the training and testing sets.
News_Train_df = preprocess_newsgroups(newsgroups_train)
News_Test_df = preprocess_newsgroups(newsgroups_test)

# Add an ID variable. 
News_Train_df['Id'] = list(range(1, News_Train_df.shape[0] + 1))
News_Test_df['Id'] = list(range(News_Train_df.shape[0] + 1, News_Train_df.shape[0] + News_Test_df.shape[0] + 1))

##########################################################################################################################################
##	Write to TSV on disk. 
##########################################################################################################################################

# Export the Labels texts to integers. 
Label_Names_df = pd.DataFrame({'Label': list(range(0,20)),
                               'LabelNames': newsgroups_train.target_names})

# Write to CSV on disk. 
News_Train_df.to_csv(os.path.join(sys.path[0], "News_Train"), sep='\t', header = True, index = False, encoding='utf-8')
News_Test_df.to_csv(os.path.join(sys.path[0], "News_Test"), sep='\t', header = True, index = False, encoding='utf-8')
Label_Names_df.to_csv(os.path.join(sys.path[0], "Label_Names"), sep='\t', header = True, index = False, encoding='utf-8')
