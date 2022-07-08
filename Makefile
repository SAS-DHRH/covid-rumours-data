################################################
# COVID Rumors in Historical Context
# School of Advanced Study, University of London
# Marty Steer and Kunika Kono, 2022
################################################
# Using gnu makefiles helps with reproducibility
# of the data pipeline.
#
# `Make` this datapackage to build local source
# data into a variety of more useful datasets
# which can be used downstream.
#
# For multithreaded data processing use:
# $ make -j 8
#
# Use these rules to help debug source & target:
# 	@echo T-source		$^
# 	@echo T-target 		$@
# 	@echo T-replace		$(^:.csv=.txt)
# 	@echo T-file-within	$(@F)
# 	@echo T-target 		$@
# 	@echo
#
################################################
# Variables
# Source data and build data directories (in and out)
DATA_DIR = ./data
BUILD_DIR = ./build
SCRIPT_DIR = ./scripts

# Source file list
SOURCE_JSONL = $(wildcard $(DATA_DIR)/*.jsonl.gz)

# ---
all:
	$(MAKE) $(MAKEFLAGS) tids users hashtags urls
	$(MAKE) $(MAKEFLAGS) languages sensitive
	$(MAKE) $(MAKEFLAGS) texts
	$(MAKE) $(MAKEFLAGS) users_daily tweets_daily

# ---
# Other targets to run separately if you need them:
# requirements
# noretweets, noretweets-en, noretweets-jp
# media-urls, media-urls-files


# ---
# tweets
# useful metadata fields from all tweets
T_CHUNKS_DIR = tweets
$(BUILD_DIR)/$(T_CHUNKS_DIR)/%.csv: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | jq -r '[.id_str, .created_at, .user.name, .user.id_str, .user.created_at, .lang, .possibly_sensitive, .quote_count, .reply_count, .retweet_count, .favorite_count] | @csv' > $@


# ---
# hashtags
# hashstags, use jq to convert to long/narrow data stream of [tid, single hashtag]
H_CHUNKS_DIR = hashtags
$(BUILD_DIR)/$(H_CHUNKS_DIR)/%.csv: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | jq -r '{id_str: .id_str, hashtags: .entities.hashtags} | {id_str: .id_str, hashtag: .hashtags[].text} | [.id_str, .hashtag] | @csv' > $@


# ---
# urls
# long/narrow data stream of [tid, single url]
URL_CHUNKS_DIR = urls
$(BUILD_DIR)/$(URL_CHUNKS_DIR)/%.csv: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | jq -r '{id_str: .id_str, urls: .entities.urls} | {id_str: .id_str, url: .urls[].expanded_url} | [.id_str, .url] | @csv' > $@


# ---
# target: tids
# The full list of tweet ID's is also the primary publishable dataset!
T_CSV = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(T_CHUNKS_DIR)/%.csv, $(SOURCE_JSONL))
tids: $(BUILD_DIR)/tids.csv.gz
$(BUILD_DIR)/tids.csv.gz: $(T_CSV)
	cat $^ | csvcut -c 1,2 | pigz > $@ && \
	gzcat $@ | wc -l > $(@:.csv.gz=-count.txt)


# ---
# target: users
# NB: personal data alert!
# Extract and summarise username frequencies (how often they tweeted)
users: $(BUILD_DIR)/users-count.txt $(BUILD_DIR)/users-created_at.csv.gz
$(BUILD_DIR)/users-count.txt: $(T_CSV)
	cat $^ | csvcut -c 3 | sort | uniq -c | sort -rn > $@

# Extract account created dates. We are looking for recently created accounts.
# i.e. "Cyber Fleets" of social media accounts.
# Get all unique [userid, create date]
$(BUILD_DIR)/users-created_at.csv.gz: $(T_CSV)
	cat $^ | csvcut -c 4,5 | pigz > $@


# ---
# target: users_daily
# Make an anonymised publishable user daily summary file for visualisation
users_daily: $(BUILD_DIR)/users-daily.csv
$(BUILD_DIR)/users-daily.csv: $(BUILD_DIR)/users-created_at.csv.gz
	gzcat $^ | xsv select 2 | \
	awk -F' ' '{mth=sprintf("%02i", (match("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC",toupper($$2))+2)/3); print $$6 "-" mth "-" $$3 " 00:00:00" }' | \
	sort | uniq -c | \
	awk 'BEGINFILE{print "created_at,user_count"}{print $$2,$$3","$$1}' > $@


# ---
# target: tweets_daily
# Make an anonymised publishable daily tweets summary file for visualisation
tweets_daily: $(BUILD_DIR)/tweets-daily.csv
$(BUILD_DIR)/tweets-daily.csv: $(BUILD_DIR)/tids.csv.gz
	gzcat $^ | xsv select 2 | \
	awk -F' ' '{mth=sprintf("%02i", (match("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC",toupper($$2))+2)/3); print $$6 "-" mth "-" $$3 " 00:00:00" }' | \
	sort | uniq -c | \
	awk 'BEGINFILE{print "created_at,tweet_count"}{print $$2,$$3","$$1}' > $@


tweets_hourly: $(BUILD_DIR)/tweets-hourly.csv
$(BUILD_DIR)/tweets-hourly.csv: $(BUILD_DIR)/tids.csv.gz
	gzcat $^ | xsv select 2 | \
	awk -F' ' '{mth=sprintf("%02i", (match("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC",toupper($$2))+2)/3); print $$6 "-" mth "-" $$3 " " substr($$4,1,2)":00:00" }' | \
	sort | uniq -c | \
	awk 'BEGINFILE{print "created_at,tweet_count"}{print $$2,$$3","$$1}' > $@


# ---
# target: languages
languages: $(BUILD_DIR)/languages-count.txt
$(BUILD_DIR)/languages-count.txt: $(T_CSV)
	cat $^ | csvcut -c 6 | sort | uniq -c | sort -rn > $@


# ---
# target: sensitive
sensitive: $(BUILD_DIR)/sensitive-count.txt
$(BUILD_DIR)/sensitive-count.txt: $(T_CSV)
	cat $^ | csvcut -c 7 | sort | uniq -c | sort -rn > $@


# ---
# target: hashtags
H_CSV = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(H_CHUNKS_DIR)/%.csv, $(SOURCE_JSONL))
hashtags: $(BUILD_DIR)/hashtags-count.txt
$(BUILD_DIR)/hashtags-count.txt: $(H_CSV)
	cat $^ | csvcut -c 2 | sort | uniq -c | sort -rn > $@


# ---
# target: urls
URL_CSV = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(URL_CHUNKS_DIR)/%.csv, $(SOURCE_JSONL))
urls: $(BUILD_DIR)/urls-count.txt
$(BUILD_DIR)/urls-count.txt: $(URL_CSV)
	cat $^ | csvcut -c 2 | sort | uniq -c | sort -rn > $@


# ---
# target: tweets-retweeted
# urls, long/narrow data stream of [id_str, quote_count, reply_count, retweet_count, favorite_count]
RETWEET_DIR = tweets-retweeted
RETWEET_CSV = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(RETWEET_DIR)/%.csv.gz, $(SOURCE_JSONL))

tweets-retweeted: $(BUILD_DIR)/tweets-retweeted-daily.csv
$(BUILD_DIR)/tweets-retweeted-daily.csv: $(RETWEET_CSV)
	python $(SCRIPT_DIR)/resample-retweets-data.py --inputdir $(<D) --output $@

$(BUILD_DIR)/$(RETWEET_DIR)/%.csv.gz: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | jq -r 'select(.retweeted_status.id_str) | [.retweeted_status.id_str, .retweeted_status.created_at, .retweeted_status.quote_count, .retweeted_status.reply_count, .retweeted_status.retweet_count, .retweeted_status.favorite_count, .retweeted_status.full_text] | @csv' | pigz > $@


# ---
# target: media-urls
MEDIA_CHUNKS_DIR = media-urls
$(BUILD_DIR)/$(MEDIA_CHUNKS_DIR)/%.csv: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | python ./bin/twarc/utils/media_urls.py > $@

# urls, long/narrow data stream of [tid, single url]
MEDIA_CSV = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(MEDIA_CHUNKS_DIR)/%.csv, $(SOURCE_JSONL))
media-urls: $(BUILD_DIR)/media-urls-count.txt
$(BUILD_DIR)/media-urls-count.txt: $(MEDIA_CSV)
	cat $^ | cut -d' ' -f2 | sort | uniq -c | sort -rn > $@


# ---
# target: media-urls-files
# Uses sed to insert headers in first line, then awk to cut last column from file and
# feed this to minet, which handles downloading the media. 
# Minet will resume/restart and capture metadata.
media-urls-files: minet $(BUILD_DIR)/media-urls-files-complete.txt
$(BUILD_DIR)/media-urls-files-complete.txt: $(BUILD_DIR)/media-urls-count.txt
	sed '1 s/^/tid url\n/' $(BUILD_DIR)/media-urls-count.txt | awk '{print $$(NF)}' | \
		minet fetch url -o $(BUILD_DIR)/media-urls-files.csv -d $(BUILD_DIR)/$(MEDIA_CHUNKS_DIR)-files --resume --folder-strategy prefix-2 && \
		touch $@


# ---
# target: noretweets
# Remove retweets from entire corpus.
NORETWEET_DIR = noretweets
NORETWEET_JSONLS = $(patsubst $(DATA_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz, $(SOURCE_JSONL))

$(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz: $(DATA_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | python ./bin/twarc/utils/noretweets.py | pigz > $@

noretweets: $(BUILD_DIR)/noretweets-done.txt
$(BUILD_DIR)/noretweets-done.txt: $(NORETWEET_JSONLS)
	touch $@


# ---
# target: noretweets-en
# english/undetermined noretweets (langcode == en or und)
EN_NORETWEET_DIR = noretweets-en
EN_NORETWEET_JSONL = $(patsubst $(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(EN_NORETWEET_DIR)/%.jsonl.gz, $(NORETWEET_JSONLS))

$(BUILD_DIR)/$(EN_NORETWEET_DIR)/%.jsonl.gz: $(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | grep -e '"lang": "en"' -e '"lang": "und"' | pigz > $@

noretweets-en: $(BUILD_DIR)/noretweets-en-done.txt
$(BUILD_DIR)/noretweets-en-done.txt: $(EN_NORETWEET_JSONL)
	touch $@

# ---
# target: japanese noretweets
JA_NORETWEET_DIR = noretweets-ja
JA_NORETWEET_JSONL = $(patsubst $(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(JA_NORETWEET_DIR)/%.jsonl.gz, $(NORETWEET_JSONLS))

$(BUILD_DIR)/$(JA_NORETWEET_DIR)/%.jsonl.gz: $(BUILD_DIR)/$(NORETWEET_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | grep '"lang": "ja"' | pigz > $@

noretweets-ja: $(BUILD_DIR)/noretweets-ja-done.txt
$(BUILD_DIR)/noretweets-ja-done.txt: $(JA_NORETWEET_JSONL)
	touch $@


# ---
# target: texts
# Uses noretweets-en
# The full text of tweets as {id, text} json lines (for downstream linguistic processes)
TXT_CHUNKS_DIR = texts
TXT_JSONL = $(patsubst $(BUILD_DIR)/$(EN_NORETWEET_DIR)/%.jsonl.gz, $(BUILD_DIR)/$(TXT_CHUNKS_DIR)/%.jsonl, $(EN_NORETWEET_JSONL))

$(BUILD_DIR)/$(TXT_CHUNKS_DIR)/%.jsonl: $(BUILD_DIR)/$(EN_NORETWEET_DIR)/%.jsonl.gz
	mkdir -p $(@D)
	gzcat $^ | jq -c '{id: .id_str, text: (if .extended_tweet.full_text then .extended_tweet.full_text else (if .full_text then .full_text else .text end) end)}' > $@

texts: $(BUILD_DIR)/texts-done.txt
$(BUILD_DIR)/texts-done.txt: $(TXT_JSONL)
	touch $@


# ---
# @requirements: based on macos
PHONY: twarc jq csvkit minet
requirements: twarc jq csvkit minet

twarc: ./bin/twarc 
./bin/twarc:
	git clone https://github.com/DocNow/twarc.git bin/twarc

jq: /usr/local/bin/jq
/usr/local/bin/jq:
	brew install jq

csvkit: /usr/local/bin/csvcut
/usr/local/bin/csvcut:
	brew install csvkit

minet: /usr/local/bin/minet
/usr/local/bin/minet:
	curl -sSL https://raw.githubusercontent.com/medialab/minet/master/scripts/install.sh | bash


# ---
.PHONY: clean
clean:
	@echo "Removing build directory..."
	rm -r $(BUILD_DIR)
