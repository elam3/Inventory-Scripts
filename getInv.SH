#!/bin/bash
# set -x
#
#   USAGE
#       getInv.SH [--WET] FILE
#
#Read in a csv of "qty,sku" and fetch 1) Product Name, 2) Product sizes, 3) _stock from database
#
## Check List
# Do a dry run
# Save the dry run results, script a tarball?
# Check gift-certificate, make sure it is still working
#  

if [ $1 = "clean" ] ; then
    rm -f output.csv error_log.txt qty.csv 
    echo "cleanup"
    exit 0
fi

if [ $# -gt 2 ] ; then
    echo "$0: ERROR: Too many arguments" >&2
    echo -e "\t usage: $0 [--WET] FILE"
    exit 1
fi

dryRun=true
while [[ $# > 0 ]] ; do
    if [[ "$1" = "--WET" ]] ; then
        dryRun=false
    elif [ -f "$1" ] ; then
        FILE="$1"
    fi  
    shift
done


#File Cleanup
rm -f output.csv error_log.txt

#Read raw data & sort into two columns of: Count, SKU
dos2unix "$FILE" &> /dev/null #need to fix newline chars before file manipulation
cat "$FILE" | sort | cut -f1 -d, | sort | uniq -c | tr -s ' ' | tr ' ' , | cut -f2- -d, > qty.csv

#Insert file headers
echo "SKU,PROD_NAME,SIZE,COUNTED,WORDPRESS_STOCK" > output.csv

#mysql login
source .env
login="mysql -u $DB_USR -p$DB_PW $DB_NAME -sNe "

#mysql backup
mysqldump -u $DB_USR -p$DB_PW $DB_NAME > bkup_sousouus_$(date +%Y_%m_%d_%T).sql

# remove credentials # doesn't do much, but do it anyways
unset DB_USR; unset DB_PW; unset DB_NAME;

# Ignore in dryRun
# mysql set all stock to 0 quantity
if [[ $dryRun == "false" ]] ; then
    $login "update wp_postmeta set meta_value = 0 where meta_key = '_stock';"
fi

line_num=0; #keep track of line number of file we are reading through in while loop
while read line
do
	line_num=$(( line_num + 1 )) #update the line number tracker
	thisQTY=$(echo "$line" | cut -f1 -d,) #store QTY to var by cutting 1st field of the read line
	thisSKU=$(echo "$line" | cut -f2 -d,) #store SKU to var by cutting 2nd field of the read line
	if [[ "$thisSKU" == "" ]] #if the sku is blank, we skip it
	then
		echo #make sure error msg is on a line by itself
		echo "line.$line_num :: empty line :: qty:$thisQTY :: sku:$thisSKU :: $(date)" | tee -a error_log.txt 1>&2
		continue
	fi

	### mysql queries
	#Start by finding the post_id, then we can find the other data
    # TODO Make sure query for post_id returns only 1 row
	post_id=$($login "select post_id from wp_postmeta where meta_key = '_sku' AND meta_value = '$thisSKU';")

	#if post_id fails to fetch, we skip
	if [[ "$post_id" == "" ]]
	then
		echo #make sure error msg is on a line by itself
		echo "$line_num : post_id not found : $thisQTY : $thisSKU" | tee -a error_log.txt 1>&2 #print error msg
		continue
	fi

	#what kind of product type is it? simple or variable
	post_type=$($login "select post_type from wp_posts where ID = '$post_id';")
	if [[ "$post_type" == "product_variation" ]]
	then
		#takes a lil more work to find post_id for variable-product-types
		parent_post_id=$($login "select post_parent from wp_posts where ID = '$post_id';")
		post_name=$($login "select post_name from wp_posts where ID = '$parent_post_id';")
		post_title=$($login "select post_title from wp_posts where ID = '$parent_post_id';")
	else
		#retrieve the product name
		post_name=$($login "select post_name from wp_posts where ID = '$post_id';")
		post_title=$($login "select post_title from wp_posts where ID = '$post_id';")
	fi

	#retrieve the stock amount according to wordpress database
	stock=$($login "select meta_value from wp_postmeta where post_id = '$post_id' AND meta_key = '_stock';")
	#retrieve the sizing for this particular product
	if [[ "$post_type" == "product_variation" ]]
	then
		size=$($login "select meta_value from wp_postmeta where post_id = '$post_id' AND meta_key LIKE '%attribute%';")
	else
		size="N/A"
	fi
	
    # Ignore in dryRun
    # Update database stock
    if [[ $dryRun == "false" ]] ; then
        $($login "update wp_postmeta set meta_value = '$thisQTY' where post_id = '$post_id' AND meta_key = '_stock';")
    fi

	#Output data to a txt file
	# $thisSKU	-	the barcode number of the current item
	# $post_title	- product name of curent item
	# $size	-	the product size variation
	# $thisQTY	-	this is the amount we counted, according to import data
	# $stock	-	this is the original/expected count on the database, prior to the update query
	echo "$thisSKU,"$post_title",$size,$thisQTY,$stock" >> output.csv
	echo -n "." # progress tracker, print a period for each iteration. get live feedback that script is still running

done < qty.csv

# Light Cleanup
#rm -f qty.csv

echo #echo blank line to mark End_of_Script
