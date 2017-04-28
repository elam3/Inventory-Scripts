#!/usr/bin/python
# Python 2.7.10
from __future__ import print_function
from math import floor
import sys, csv

header = []

# Build Dictionary of output.csv
reconcile = {}
with open("output.csv", "rb") as f:
    reader = csv.reader(f)
    row_num = 1
    for row in reader:
        if len(row) == 5 :
            if row_num == 1:
                header = row
                header.append("DIFF(D-E)")
            else :
                sku = row[0]
                reconcile[sku] = [
                        row[0],     #"sku"       :
                        row[1],     #"name"      :
                        row[2],     #"size"      :
                        "0" if row[3]=="" else str(int(floor(float(row[3])))),      #"count"  :
                        "0" if row[4]=="" else str(int(floor(float(row[4]))))       #"wp_count"  :
                ]
                diff = str(int(reconcile[sku][3]) - int(reconcile[sku][4]))
                reconcile[sku].append(diff)
        row_num += 1
    # end for row in reader
# end with open output.csv

f_num = 1
files = len(sys.argv)
while f_num < files :
    print(sys.argv[f_num])
    filename = sys.argv[f_num]
    location = filename[22:]
    location = location[:-4]
    sheet = {}

    with open(filename, 'rb') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) == 0:
                continue
            sku = row[0] # type str
            count = sheet.get(sku)
            count = 1 if count is None else count + 1
            sheet[sku] = count
        # end for
        for key,value in sheet.items():
            if len(key)==0:
                continue
            if reconcile.get(key) is None:
                continue
            reconcile[key].append(location)
            reconcile[key].append(value)
        # end for key,value in sheet
    # end with
    f_num += 1
# end while


with open("test.csv", "wb") as f:
    writer = csv.writer(f)
    writer.writerow(header)
    for key,value in reconcile.items():
        writer.writerow(value)


with open("test.min.csv", "wb") as f:
    writer = csv.writer(f)
    writer.writerow(header)
    for key,value in reconcile.items():
        if value[5] == "0":
            continue
        writer.writerow(value)

