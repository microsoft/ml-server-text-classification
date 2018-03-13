import pandas as pd
import numpy as np
import re, os, gzip, requests

# load raw data from a .tsv.gz file into Pandas data frame.
def read_csv_gz(url, **kwargs):
    df = pd.read_csv(gzip.open(requests.get(url, stream=True).raw, mode='rb'), sep='\t', encoding='utf8', **kwargs)
    return df.set_index('Id')

# URLs to Original questions, Duplications, and Answers.
questions_url = 'https://bostondata.blob.core.windows.net/stackoverflow/orig-q.tsv.gz'
dupes_url = 'https://bostondata.blob.core.windows.net/stackoverflow/dup-q.tsv.gz'
answers_url = 'https://bostondata.blob.core.windows.net/stackoverflow/ans.tsv.gz'

# load datasets.
questions = read_csv_gz(questions_url, names=('Id', 'AnswerId', 'Text0', 'CreationDate'))
dupes = read_csv_gz(dupes_url, names=('Id', 'AnswerId', 'Text0', 'CreationDate'))
answers = read_csv_gz(answers_url, names=('Id', 'Text0'))


def clean_text(text):
    global EMPTY
    EMPTY = ''
    if not isinstance(text, str): 
        return text
    text = re.sub('<pre><code>.*?</code></pre>', EMPTY, text)
    def replace_link(match):
        return EMPTY if re.match('[a-z]+://', match.group(1)) else match.group(1)
    
    text = re.sub('<a[^>]+>(.*)</a>', replace_link, text)
    return re.sub('<[^>]+>', EMPTY, text)

for df in (questions, dupes, answers):
    df['Text'] = df['Text0'].apply(clean_text).str.lower()
    df['NumChars'] = df['Text'].str.len()


# find the AnswerIds has at least 3 dupes.
def find_answerId(answersC, dupesC, num_dupes): 
    countHash = {}
    for i in dupesC.AnswerId:
        if i not in answersC.index.values:
            continue
        if i not in countHash.keys():
            countHash[i] = 1
        else:
            countHash[i] += 1
    countHash = {k: v for k, v in countHash.items() if v >= num_dupes}
    commonAnswerId = countHash.keys()
    return commonAnswerId

# extract data based on the selection criteria.
def select_data(questions, dupes, answers):
    # exclude the records without any text
    questions_nz = questions.query('NumChars > 0')
    dupes_nz = dupes.query('NumChars > 0')
    answers_nz = answers.query('NumChars > 0')

    # get the 10th percentile of text length as the minimum length of characters to consider in the text field
    minLenQ = questions_nz.quantile(.1)['NumChars']
    minLenD = dupes_nz.quantile(.1)['NumChars']
    minLenA = answers_nz.quantile(.1)['NumChars']
    
    # eliminate records with text less than the minimum length
    questionsC = questions.query('NumChars >' + str(int(minLenQ)))
    dupesC = dupes.query('NumChars >' + str(minLenD))
    answersC = answers.query('NumChars >' + str(minLenA))
    
    # remove the records in dupesC whose questionId has already existed in questionsC
    duplicatedIndex = list(set(questionsC.index).intersection(set(dupesC.index)))
    dupesC.drop(duplicatedIndex, inplace=True)
    
    # make sure Questions 1:1 match with Answers 
    matches = questionsC.merge(answersC, left_on = 'AnswerId', right_index = True)
    questionsC = matches[['AnswerId', 'Text0_x', 'CreationDate', 'Text_x', 'NumChars_x']]
    questionsC.columns = ['AnswerId', 'Text0', 'CreationDate', 'Text', 'NumChars']

    answersC = matches[['Text0_y', 'Text_y', 'NumChars_y']]
    answersC.index = matches['AnswerId']
    answersC.columns = ['Text0', 'Text', 'NumChars']
    
    # find the AnswerIds has at least 3 dupes
    commonAnswerId = find_answerId(answersC, dupesC, 3)
    
    # select the records with those AnswerIds
    questionsC = questionsC.loc[questionsC.AnswerId.isin(commonAnswerId)]
    dupesC = dupesC.loc[dupesC.AnswerId.isin(commonAnswerId)]
    
    return questionsC, dupesC

# some questions have been linked to multiple AnswerIds.
# we keep the first AnswerId associated with that question and remove the rest.
questions = questions.groupby(questions.index).first()
dupes = dupes.groupby(dupes.index).first()

# execute the data selection function on questions, dupes and answers.
questionsC, dupesC = select_data(questions, dupes, answers)

# split Original questions and their Duplications into training and test sets.
def split_data(questions, dupes, frac):
    trainQ = questions
    testQ = pd.DataFrame(columns = dupes.columns.values) # create an empty data frame

    for answerId in np.unique(dupes.AnswerId):
        df = dupes.query('AnswerId == ' + str(answerId))
        totalCount = len(df)
        splitPoint = int(totalCount * frac)
        dfSort = df.sort_values(by = ['CreationDate'])
        trainQ = trainQ.append(dfSort.head(splitPoint)) # oldest N percent of duplications
        testQ = testQ.append(dfSort.tail(totalCount - splitPoint))

    # convert data type to int
    testQ[["AnswerId", "NumChars"]] = testQ[["AnswerId", "NumChars"]].astype(int) 
    # rename the index 
    testQ.index.rename("Id", inplace=True)
    
    return trainQ, testQ

trainQ, testQ = split_data(questionsC, dupesC, 0.75)

# Save to disk. 
countPerAns = pd.DataFrame({"NumTrain" : trainQ.groupby("AnswerId").size()})
trainQwithCount = trainQ.merge(countPerAns, left_on="AnswerId", right_index=True)
testQwithCount = testQ.merge(countPerAns, left_on="AnswerId", right_index=True)

# for each Answer class, we request more than 13 training questions.
trainQ = trainQwithCount[trainQwithCount["NumTrain"] > 13]
testQ = testQwithCount[testQwithCount["NumTrain"] > 13]

# Remove NumTrain and NumChars. 
trainQ = trainQ.drop('NumTrain', 1)
trainQ =  trainQ.drop('NumChars', 1)
trainQ =  trainQ.drop('Text0', 1)
trainQ =  trainQ.drop('CreationDate', 1)
testQ =  testQ.drop('NumTrain', 1)
testQ =  testQ.drop('NumChars', 1)
testQ =  testQ.drop('Text0', 1)
testQ =  testQ.drop('CreationDate', 1)

trainQ.to_csv('trainQsm', sep='\t', header=True, index=True, index_label='Id')
testQ.to_csv('testQsm', sep='\t', header=True, index=True, index_label='Id')