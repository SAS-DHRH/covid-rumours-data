# Covid Rumours in Historical Context

*Notes on post-harvest raw data processing*

**JSON validity check, deduplication, chunk into date files.**

This was used to chunk the original twarc data for Corpus Gamma (γ). I'm leaving it here for info. The chunking was done manually and the results/issues are documented below. This was necessary to validate the JSON (there are the occasional instance of byte-encoding injection attacks which break the JSON syntax).

#### e.g. Corpus γ coverage
**Start:** 2021-09-22\
**End:** 2022-01-10\
**Number of lines before:** 6628406 (`$ gzcat data/*.gz | wc -l`)\
**Number of lines after:** 6626168\
**Number of files before:** 112\
**Number of files after:** 113

### Processing steps

0) gzip and move twarc.log and all-filter.jsonl into ./logs and ./data respectively. These contain the data which was not yet logrotated.
1) Process to remove first and last lines and use `jq` to validate the jsonl.
2) deduplicate any tweets! Some back-dated searches were done, so this dealt with those.
3) Split tweets into daily files (according to their tweet timestamp). Some of the log rotations were out by a day. e.g yesterday's tweets were rotated into today's zip file at 01:00.
4) Add to data version control.
5) Commit to git repository
6) Push data to the secure enclave
7) Run the Makefile to build (optional)

---

1) bash command to top and tail the first and last line from each daily zip file. This also shows up which original files have json parse errors so they can be manually fixed (needs jq and pigz commands).

```bash
mkdir chunks
for f in *.gz
do
	echo ${f%.gz}
	gzcat "$f" | awk 'NR>2 {print last} {last=$0}' | jq -S -c '.' | pigz > ./chunks/"$f"
done
```

> Errors appear like this. Each file can then be unzipped, the line found and removed and individually processed again:
>
> ```
> all-filter.2021-03-09.jsonl.gz
> parse error: Invalid numeric literal at line 589, column 7089
> all-filter.2021-03-10.jsonl.gz
> all-filter.2021-03-11.jsonl.gz
> all-filter.2021-03-12.jsonl.gz
> all-filter.2021-03-13.jsonl.gz
> all-filter.2021-03-14.jsonl.gz
> all-filter.2021-03-15.jsonl.gz
> all-filter.2021-03-16.jsonl.gz
> all-filter.2021-03-17.jsonl.gz
> parse error: Expected separator between values at line 25234, column 1
> all-filter.2021-03-18.jsonl.gz
> ```

Once all files are processed put the validated .gz files back into the data directory overwriting the original data (the original data was still on the raspberry pi, so could refresh when mistakes were made - and they were!).

2. This next one command is very terse, but puts all unique tweets into daily files. It deduplicates the tweets and sorts the JSON field names, which results in the date column being in a predictable parts of the jsonl so awk can grab the date string. It then converts the month (Jan/Feb/Mar...etc.) to an integer (by matching the characters in the string and calculating the character index). The date values are then used in the output filename (`rona-rumours-corpus-γ-2020-01-01.jsonl.gz`) and the JSON is piped and gzipped into the appropriate daily file. Takes about an hour or two to process this bit on a Intel i7.

```bash
make ./bin/twarc
cd data
gzcat *.jsonl.gz | ../bin/twarc/utils/deduplicate.py | jq -S -c '.' | awk -F' ' '{d=substr($6,0,4) "-" sprintf("%02i", (match("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC",toupper($2))+2)/3) "-" $3; print | "pigz > ./rona-rumours-corpus-γ-" d ".jsonl.gz"}'
```

4., 5. and 6. Now we remove all the old files and add the newly renamed daily corpus files to data version control:

```bash
rm all-filter*.jsonl.gz
cd ..
dvc add ./data
dvc add ./logs
git add .
git commit -m 'add data'
dvc push
```

7. (optional) `make` will extract and preprocess a lot of data and store it in the `./build` directory for downstream processing/use. The flag `-j8` uses 8 CPU cores for parrallel processing.

```
make -j8
dvc add build/tweets
dvc add build/hashtags

...etc...

git add .
git commit -m 'add build data'
dvc push
```

@see [covid-rumours](https://github.com/SAS-DHRH/covid-rumours) and [covid-rumours-dashboard](https://github.com/SAS-DHRH/covid-rumours-dashboard) for downstream use.

<br />

\---
