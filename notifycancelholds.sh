#!/bin/bash
####################################################
#
# Bash shell script for project notifycancelholds.sh 
#
# Notifies users and cancels holds on titles with no viable copies.
#    Copyright (C) 2016  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Copyright (c) Mon Jun 22 15:51:12 MDT 2016
# Rev: 
#          1.00.01 - New release to use mailerbothtml.sh instead of mailerbot.pl.
#          0.6_03 - Fix mis-use of $HOME.
#          0.6_02 - Add test for addnote.pl.
#          0.6_01 - Removed LOST, LOST-ASSUM as exclusion criteria. Now just LOST-ASSUM only.
#          0.6_00 - No longer accepts a single cat key as argument, removed BIN_CUSTOM variable, cleaned and tested API.
#          0.5_13 - Selection to not include ILL-BOOK.
#          0.5_12 - Revisit and refactor.
#          0.5_11 - cancelholds.pl not a dependancy for this script. Removing.
#          0.5_10 - Added -i to run interactively. Default just run.
#          0.5_09 - Fix bug in output of opacsearchlink.pl and put unlinked titles on customer accounts.
#          0.5_08 - Add dynamic link handling through opacsearchlink.pl.
#          0.5_07 - Send message as HTML.
#          0.5_06 - Broadened  selection to just not select MISSING, LOST-ASSUM, and LOST items.
#          0.5_05 - Optimized selection criteria at selcatalog stage.
#          0.5_04 - Changes to non-emailed account message.
#          0.5_03 - Changes recommended by staff 
#                   July 22, 2015: hold Cancelled, no copies available � title 07/22/2015
#          0.5_02 - Added count to confirm message. 
#          0.5_01 - Updated to use new mask of pipe.pl. 
#          0.5 - Experimental use of search URL in holdbot.pl -s. 
#          0.4 - Widen the title string for better read-ability. 
#          0.3 - API selection re-work for MISSING and LOST-ASSUM. 
#          0.2 - Take a catalogue key as an argument. 
#          0.1 - Basic infrastructure. 
#          0.0 - Dev.
# Dependencies: holdbot.pl, 
#               pipe.pl,
#               mailerbothtml.pl
#               opacsearchlink.pl
#
####################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
. ~/.bashrc
###############################################
VERSION='1.00.01'
DATE=` date +%Y%m%d`
CANCEL_DATE=`date +%m/%d/%Y`
# If an item was charged out and became LOST-ASSUM, wait this amount of time before 
# cancelling the holds. The reason is; what if someone returns the item, but the holds
# have been cancelled? Turns out the lending period (21 days) + days as LOST-ASSUM = 51
# call it 60. After that it is extremely unlikely that the item will be recovered.
LAST_ACTIVE_DATE_THRESHOLD=`transdate -d-60`
WORK_DIR=~/Unicorn/EPLwork/cronjobscripts/Notifycancelholds
BIN_CUSTOM=~/Unicorn/Bincustom
LOG=$WORK_DIR/notification.log
echo " -- starting $0 version $VERSION --"
# Find and test for all our dependencies.
if [ ! -e "$BIN_CUSTOM/holdbot.pl" ]
then
	echo "** error: key component 'holdbot.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/mailerbothtml.sh" ]
then
	echo "** error: key component 'mailerbothtml.sh' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/pipe.pl" ]
then
	echo "** error: key component 'pipe.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/opacsearchlink.pl" ]
then
	echo "** error: key component 'opacsearchlink.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/addnote.pl" ]
then
	echo "** error: key component 'addnote.pl' missing!"
	exit 1;
fi
cd $WORK_DIR
COUNT=0
echo "Starting data collection..."
################### Cancel all titles with zero visible items ######################
# API for selecting items with 0 visible copies with the caveat that we don't want
# missing items since they could be found in short order and by then we may have cancelled
# many holds creating frustration and confusion for customers. We don't want LOST-ASSUM
# that are younger than 60 days for the same reason, they get converted to LOST, then discard 
# in due time (30 days).
# API: sel cat records with holds>0 but 0 visible call nums. Select the holds make sure they're active, then get those items 
# and make sure those items aren't marked LOST MISSING LOST-ASSUM in case they show up, and make sure they aren't ILL-BOOKs;
# we don't want to cancel ILL holds; they fit this discription.

# Initially we look for all the cat keys of titles with no visible copies and holds, output the item keys.
selcatalog -z0 -h">0" 2>/dev/null | selitem -iC -oImta | pipe.pl -dc0,c1,c2 > all.items.lst.$DATE.tmp$$
# An additional selection should be made for corner cases where the holds are on visible, but non-holdable items like REF-BOOK.
# This can happen if staff place a hold for customers(?). Uncomment the line below to turn this feature on. It is tested.
# This can be expanded to HITS2GO as well.
####### **** BE VERY CAREFUL IF YOU DECIDE TO DO THIS, SOME TITLES HAVE A MIXTURE OF BOOK and REF-BOOK. The BOOK holds will be cancelled. ****#####
### selitem -tREF-BOOK -oCmta | selhold -iC -tT -jACTIVE -oIS 2>/dev/null | pipe.pl -dc0,c1,c2 >> all.items.lst.$DATE.tmp$$
# 1001225|13|2|DISCARD|JPBK|20160708|
# 1001225|2|1|LOST-ASSUM|JPBK|20160708|
# 1001225|24|2|DISCARD|JPBK|20160708|
# 1001225|2|6|DISCARD|JPBK|20160708|
# 1001225|26|2|DISCARD|JPBK|20160708|
# 1001225|26|4|DISCARD|JPBK|20160708|
# 1001225|2|7|DISCARD|JPBK|20160708|
# 1001225|33|2|DISCARD|JPBK|20160708|
# 1001225|43|1|DISCARD|JPBK|20160708|
# 1001225|46|1|DISCARD|JPBK|20160708|
### Additional REF-BOOK selections look like this.
# 11246|75|1|DISCARD|REF-BOOK|20160708|
# 1157980|2|7|CHECKEDOUT|REF-BOOK|20160708|
# 117968|330|1|DISCARD|REF-BOOK|20160708|
# 1233078|93|1|CHECKEDOUT|REF-BOOK|20160708|
# 128866|22|2|CHECKEDOUT|REF-BOOK|20160708|

# Next we dedup for all cat keys regardless. After this we will exclude cat keys that have 
# items with locations that may be returned to circulation.
cat all.items.lst.$DATE.tmp$$ | pipe.pl -dc0 -oc0 -P > all.catkeys.$DATE.tmp$$
# 1002661|
# 1014715|
# 1021769|
# 1022058|
# 1023605|
# 103625|
# 1060476|
# 1067359|
# 1073072|
# 1076498|

# Now make a list of all cat keys that have items that have items in locations that may be returned.
# CHECKEDOUT - definitely coming back; low lost-ness.
# MISSING - Sometimes good results on finding items especially after a move; mid lost-less-ness.
# LOST-ASSUM - Customer billed for item, so sometimes they scurry, search and return; high lost-less-ness.
cat all.items.lst.$DATE.tmp$$ | pipe.pl -g'c3:CHECKEDOUT|MISSING|LOST-ASSUM' | pipe.pl -C"c5:gt$LAST_ACTIVE_DATE_THRESHOLD" | pipe.pl -dc0 -oc0 -P > all.catkeys.lost.missing.$DATE.tmp$$
# This grabs the ILL-BOOK item types. -g is a logical AND operation.
cat all.items.lst.$DATE.tmp$$ | pipe.pl -g'c4:ILL' | pipe.pl -dc0 -oc0 -P >> all.catkeys.lost.missing.$DATE.tmp$$

# Take the difference of the 2 files, that is report the cat keys from all catkeys 
# that don't appear in catkeys of missing and lost items. 
echo "all.catkeys.$DATE.tmp$$ not all.catkeys.lost.missing.$DATE.tmp$$" | diff.pl -ec0 -fc0 > catkeys.to.cancel.lst.$DATE.tmp$$
# 215638|
# 917953|
# 1168751|
# 807493|
# 401774|
# 1273847|
# 1484915|
# 1200862|
# 1419303|
# 1174381|
# With this refined list collect the user data. 
# Added -tT on selhold to only select title holds. System cards place copy holds and we don't want to cancel them.
cat catkeys.to.cancel.lst.$DATE.tmp$$ | selhold -iC -j"ACTIVE" -tT -oIUp | selitem -iI -oCSB | pipe.pl -m"c3:$DATE|#" > $WORK_DIR/cat_keys_$DATE.tmp$$
# 1838308|932430|20161005|20161104|1838308-1001
# 1838308|861341|20161006|20161104|1838308-1001
# 1839976|336759|20161002|20161104|1839976-1001
# 1842005|487441|20161006|20161104|1842005-1001
# 1842005|934799|20161011|20161104|1842005-1001
# 1842005|931068|20161012|20161104|1842005-1001
# 1842005|291281|20161015|20161104|1842005-1001
# 1842005|37568|20161019|20161104|1842005-1001
# 1842006|37568|20161019|20161104|1842006-1001
# 1845355|320320|20161019|20161104|1845355-1001

# Clean up these files; they are confusing because they include intermediate data that is misleading.
rm catkeys.to.cancel.lst.$DATE.tmp$$
rm all.items.lst.$DATE.tmp$$
rm all.catkeys.$DATE.tmp$$
rm all.catkeys.lost.missing.$DATE.tmp$$
if [ -s "$WORK_DIR/cat_keys_$DATE.tmp$$" ]
then
	# Make a log of the holds we are going to cancel.
	echo "[ catkey | UserKey | DatePlaced | DateCancelled | ItemID ]" > $WORK_DIR/cancelled_holds_data.$DATE.log
	cat $WORK_DIR/cat_keys_$DATE.tmp$$ >>$WORK_DIR/cancelled_holds_data.$DATE.log
	# Holdbot requires just cat keys on input so trim off the rest of the line and dedup so we don't rerun on same title, sort numerically. This will fail if you accidentally don't have a cat key in the first columns.
	cat $WORK_DIR/cat_keys_$DATE.tmp$$ | pipe.pl -oc0 -dc0 -sc0 -U >$WORK_DIR/cat_keys_$DATE.lst
	if [ -s "$WORK_DIR/cat_keys_$DATE.lst" ]
	then
		COUNT=`cat $WORK_DIR/cat_keys_$DATE.lst | wc -l`
		rm $WORK_DIR/cat_keys_$DATE.tmp$$ # We have already added it to the log so removing ok.
	else
		echo "*** error $WORK_DIR/cat_keys_$DATE.lst not created."
		exit 1
	fi
else
	echo "nothing to process."
	exit 0
fi
# The script user can bail here if they just want to review the catalog keys.
echo -n "I have collected $COUNT catalogue keys. Continue cancelling holds on item with no visible copies? y[n]: "
if [ $# == 0 ]
then
	read imsure
	if [ "$imsure" != "y" ]
	then
		echo "... it's ok to be cautious, exiting."
		exit 1
	fi
fi

if [ -s "$WORK_DIR/cat_keys_$DATE.lst" ]
then
	# Cancel holds for these items on these titles.
	cat $WORK_DIR/cat_keys_$DATE.lst | holdbot.pl -ctU >$WORK_DIR/no_link_notify_users_$DATE.lst
	# 21221018015922|It's alive [sound recording] / Ramones|
	# 21221024937960|Japanese ink painting : the art of sum�-e / Naomi Okamoto|
	# 21221021982829|To the top of Everest / Laurie Skreslet with Elizabeth MacLeod|
	# 21221015727818|Best of [sound recording] / Stampeders|
	# 21221023784330|Best of [sound recording] / Stampeders|
	# 21221021832057|Best of [sound recording] / Stampeders|
	# 21221003324842|Best of [sound recording] / Stampeders|
	# 21221018796570|Best of [sound recording] / Stampeders|
	# 21221022600958|Best of [sound recording] / Stampeders|
	# 21221020262306|Best of [sound recording] / Stampeders|
	# 21221024926807|Best of [sound recording] / Stampeders|
	# 21221022062779|Best of [sound recording] / Stampeders|
	# 21221024060748|The mole sisters and the blue egg / written and illustrated by Roslyn Schwartz|
	# 21221022448788|A caress of twilight / Laurell K. Hamilton|
	
	# Add me to the list to receive an email each time script is runs.
	head -1  $WORK_DIR/no_link_notify_users_$DATE.lst | pipe.pl -m'c0:#####_019003992' >>$WORK_DIR/no_link_notify_users_$DATE.lst
	
	# Create title links for convient searching from within the email we send.
	cat $WORK_DIR/no_link_notify_users_$DATE.lst | opacsearchlink.pl -a -f'c1,c2,c3,c4,c5,c6,c7' >$WORK_DIR/notify_users_$DATE.lst
	# 21221018015922|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=It%27s%20alive%20%5Bsound%20recording%5D">It's alive [sound recording] / Ramones</a><br/>||
	# 21221024937960|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=Japanese%20ink%20painting%20%3A%20the%20art%20of%20sum�\055%2De">Japanese ink painting : the art of sum�\055-e / Naomi Okamoto</a><br/>||
	# 21221021982829|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=To%20the%20top%20of%20Everest">To the top of Everest / Laurie Skreslet with Elizabeth MacLeod</a><br/>||
	# 21221015727818|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=Best%20of%20%5Bsound%20recording%5D">Best of [sound recording] / Stampeders</a><br/>||
	# 21221023784330|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=Best%20of%20%5Bsound%20recording%5D">Best of [sound recording] / Stampeders</a><br/>||
	# 21221021832057|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=Best%20of%20%5Bsound%20recording%5D">Best of [sound recording] / Stampeders</a><br/>||
	# 21221003324842|<a href="https://epl.bibliocommons.com/search?&t=smart&search_category=keyword&q=Best%20of%20%5Bsound%20recording%5D">Best of [sound recording] / Stampeders</a><br/>||
	
	if [ -s "$WORK_DIR/notify_users_$DATE.lst" ]
	then
		mailerbothtml.sh --log_file=$LOG --subject="EPL will be unable to fulfill your hold" --customers="$WORK_DIR/notify_users_$DATE.lst" --template="$WORK_DIR/OnOrderCancelHoldNotice.html"
		# Remove me from the customer list so I don't get multiple notes on my account every time this runs.
		grep -v "019003992" $WORK_DIR/no_link_notify_users_$DATE.lst >/tmp/scratch.tmp
		cp /tmp/scratch.tmp $WORK_DIR/no_link_notify_users_$DATE.lst
		echo "reading in the customers file..."
		while IFS='' read -r line || [[ -n $line ]]; do
			message=`echo "$line" | pipe.pl -o'c1' -m'c1:Hold cancelled\, no copies available -CMA- #######################_... '`$CANCEL_DATE
			customer=`echo "$line" | pipe.pl -o'c0'`
			echo "read '$message' for customer '$customer'"
			echo "$customer" | addnote.pl -q -m"$message"
		done < "$WORK_DIR/no_link_notify_users_$DATE.lst"
		echo "finished adding notes to customer accounts"
	else
		echo "'$WORK_DIR/notify_users_$DATE.lst' not created, nothing to do."
	fi
else
	echo "no non-visible titles have holds."
fi
# EOF


