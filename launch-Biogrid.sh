#!/bin/bash

# run the splitted Biogrid database to avoid "Out of Memory" error

touch log/general.log;

echo "== Run starts at `date +%F\ %T`" >> log/general.log;

for file in `ls BIOGRID/parts/ | grep -v ^d`; do

	echo -e "$file\t`date +%F\ %T`\t[start]" >> log/general.log

	perl main-Biogrid.pl -v --path BIOGRID/parts/$file --parse biogrid --database ppimapbuilder --host localhost --port 5432 --user ppimapbuilder --password ppimapbuilder > log/$file.log

	echo -e "$file\t`date +%F\ %T`\t[finish]" >> log/general.log
	sleep 5
done;

echo "-- Run ends at `date +%F\ %T`" >> log/general.log;


