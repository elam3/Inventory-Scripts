#!/bin/bash

dos2unix *.csv &>/dev/null
sed -i'' -e '$a\' *.csv
filename="inv_$(date +%m%d).csv"
rm -f "$filename"
cat *.csv > "$filename"
