#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Feed resample-retweets-data.py a dierctroy of csv.gz files and it will generate
daily summary of retweeted tweets.

Example usage:
resample-retweets-data.py --inputdir ./build/retweeted-tweets --output ./build/retweeted-tweets-daily.csv
"""
from __future__ import print_function

import gzip, glob, os, argparse

import pandas as pd
from tqdm import tqdm


def main(inputdir, outputfile):
    colNames = "id_str, created_at, quote_count, reply_count, retweet_count, favorite_count, text".split(', ')
    dflist = []

    for filename in tqdm(sorted(glob.glob(os.path.join(inputdir, '*.csv.gz')))):
        data = pd.read_csv(filename, names=colNames, parse_dates=[1], infer_datetime_format=True, cache_dates=True)
        dflist.append(data)

    # concat, tidyup and return. pd.concat is much faster than df.append
    df = pd.concat(dflist, ignore_index=True)
    df = df.drop('text', axis=1).fillna(0)
    df = df.astype({'id_str': int, 'quote_count': int, 'reply_count': int, 'retweet_count': int, 'favorite_count': int})
    df = df.set_index('id_str')

    # These numbers are the counts recieved from twitter over time, so only the latest/maximum value
    # per tweet is relevant. Therefore, for each column we group by tweet id and get the maximum value
    # for each group, then change index (which drops the id column) and resample for hourly frequencies.
    rtdf = df.reset_index()[['id_str', 'created_at']].drop_duplicates().set_index('id_str').sort_index()
    rtdf['quote_count'] = df['quote_count'].groupby('id_str').max().reset_index().set_index('id_str')
    rtdf['reply_count'] = df['reply_count'].groupby('id_str').max().reset_index().set_index('id_str')
    rtdf['retweet_count'] = df['retweet_count'].groupby('id_str').max().reset_index().set_index('id_str')
    rtdf['favorite_count'] = df['favorite_count'].groupby('id_str').max().reset_index().set_index('id_str')
    rtdf = rtdf.set_index('created_at').sort_index()

    # hourly file (this is a secondary output file)
    dfhourly = rtdf.resample('H').sum()  # hourly
    hourlyoutputfile = outputfile.replace('tweets-retweeted-daily', 'tweets-retweeted-hourly')
    dfhourly.to_csv(hourlyoutputfile)

    # daily file (this is the primary output file)
    rtdf = rtdf.resample('D').sum()  # daily
    rtdf.to_csv(outputfile)
    
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process a directory of retweeted tweets CSV metadata files into a daily summary file.")
    parser.add_argument('-i', '--inputdir', metavar='INFILE', required=True, help='Input directory. Files *.csv.gz will be used.')
    parser.add_argument('-o', '--outputfile', metavar='OUTFILE', required=True, help='Output filename')
    args = parser.parse_args()
    
    main(inputdir=args.inputdir, outputfile=args.outputfile)
