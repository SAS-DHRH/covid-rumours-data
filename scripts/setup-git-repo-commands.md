# Covid Rumours in Historical Context

*Notes on setup of git repo*

These commands built the repo, and added the majority of the data files to data version control. They are here for reference:

```bash
git init
dvc init
dvc remote add -d marjory ssh://marjory/home/dvcremotes
dvc add data/*.jsonl.gz
dvc add logs/*.log.zip
git add .
git commit -m 'initial commit'
dvc push
git remote add origin git@ssh.github.com:/sas-dhrh/covid-rumours-data
git push -u origin --all
```

<br />

\---