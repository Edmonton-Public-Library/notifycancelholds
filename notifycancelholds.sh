#!/bin/bash
####################################################
#
# Bash shell script for project notifycancelholds.sh 
# Purpose:
# Method:
#
# Notifies users and cancels holds on titles with no viable copies.
#    Copyright (C) 2015  Andrew Nisbet
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
# Copyright (c) Mon Jun 22 15:51:12 MDT 2015
# Rev: 
#          0.3 - API selection re-work for MISSING and LOST-ASSUM. 
#          0.2 - Take a catalogue key as an argument. 
#          0.1 - Basic infrastructure. 
#          0.0 - Dev.
# Dependencies: holdbot.pl, 
#               cancelholds.pl,
#               pipe.pl,
#               mailerbot.pl
#
####################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
source /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################
VERSION=0.3
DATE=` date +%Y%m%d`
CANCEL_DATE=`date +%Y.%m.%d`
# If an item was charged out and became LOST-ASSUM, wait this amount of time before 
# cancelling the holds. The reason is; what if someone returns the item, but the holds
# have been cancelled? Turns out the lending period (21 days) + days as LOST-ASSUM = 51
# call it 60. After that it is extremely unlikely that the item will be recovered.
LOST_ASSUM_CHARGE_DATE_THRESHOLD=`transdate -d-60` # 60 days ago.
HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Notifycancelholds
BIN_CUSTOM=/s/sirsi/Unicorn/Bincustom
# Find and test for all our dependencies.
if [ ! -e "$BIN_CUSTOM/cancelholds.pl" ]
then
	echo "** error: key component '$BIN_CUSTOM/cancelholds.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/holdbot.pl" ]
then
	echo "** error: key component '$BIN_CUSTOM/holdbot.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/mailerbot.pl" ]
then
	echo "** error: key component '$BIN_CUSTOM/mailerbot.pl' missing!"
	exit 1;
fi
if [ ! -e "$BIN_CUSTOM/pipe.pl" ]
then
	echo "** error: key component '$BIN_CUSTOM/pipe.pl' missing!"
	exit 1;
fi
cd $HOME
if [ $# == 1 ]
then
	echo "request to cancel holds on '$1'..."
	echo $1 > $HOME/cat_keys_$DATE.lst
else
	# Let's just make sure the person running this has read the warning above.
	echo -n "Are you sure you want to continue cancelling holds on item with no visible copies? y[n]: "
	read imsure
	if [ "$imsure" != "y" ]
	then
		echo "... it's ok to be cautious, exiting."
		exit 1
	fi
	echo "Starting data collection..."
	################### Cancel all titles with zero visible items ######################
	# API for selecting items with 0 visible copies with the caveat that we don't want
	# missing items since they could be found in short order and by then we may have cancelled
	# many holds creating frustration and confusion for customers. We don't want LOST-ASSUM
	# that are younger than 60 days for the same reason. They eventually get checked out to discard.
	selitem -m"~MISSING" -n"<$LOST_ASSUM_CHARGE_DATE_THRESHOLD" -oC 2>/dev/null | sort -u | selcatalog -z"=0" -iC -h">0" 2>/dev/null | selhold -iC -j"ACTIVE" -a"N" -oIUp 2>/dev/null | selitem -iI -oCSB 2>/dev/null | $BIN_CUSTOM/pipe.pl -m"c3:$DATE|@" > $HOME/cat_keys_$DATE.tmp$$
	if [ -s "$HOME/cat_keys_$DATE.tmp$$" ]
	then
		cat $HOME/cat_keys_$DATE.tmp$$ >>$HOME/cancelled_holds_data.log
		# Holdbot requires just cat keys on input so trim off the rest of the line.
		cat $HOME/cat_keys_$DATE.tmp$$ | $BIN_CUSTOM/pipe.pl -o"c0" >$HOME/cat_keys_$DATE.lst
		if [ -s "$HOME/cat_keys_$DATE.lst" ]
		then
			rm $HOME/cat_keys_$DATE.tmp$$
		else
			echo "*** error $HOME/cat_keys_$DATE.lst not created."
			exit 1
		fi
	else
		echo "nothing to process."
		exit 0
	fi
fi

if [ -s "$HOME/cat_keys_$DATE.lst" ]
then
	cat $HOME/cat_keys_$DATE.lst | $BIN_CUSTOM/holdbot.pl -cU >$HOME/notify_users_$DATE.lst 
	if [ -s "$HOME/notify_users_$DATE.lst" ]
	then
		$BIN_CUSTOM/mailerbot.pl -c"$HOME/notify_users_$DATE.lst" -n"$HOME/cancel_holds_message.txt" >$HOME/undeliverable_$DATE.lst
		# Now use the undeliverable list and add a note on the customers account.
		# It will be adequate to use the first 15 characters of the title and a short message to the account.
		if [ -s "$HOME/undeliverable_$DATE.lst" ]
		then
			# IFS='' (or IFS=) prevents leading/trailing whitespace from being trimmed.
			# -r prevents backslash escapes from being interpreted.
			# || [[ -n $line ]] prevents the last line from being ignored if it 
			# doesn't end with a \n (since read returns a non-zero exit code 
			# when it encounters EOF).
			echo "reading in the undeliverable customers file..."
			while IFS='' read -r line || [[ -n $line ]]; do
				message=`echo "$line" | $BIN_CUSTOM/pipe.pl -o'c1' -m'c1:Cancelled hold on @@@@@@@@@@@@@@@... -'`$CANCEL_DATE
				customer=`echo "$line" | $BIN_CUSTOM/pipe.pl -o'c0'`
				echo "read '$message' for customer '$customer'"
				echo "$customer" | $BIN_CUSTOM/addnote.pl -U -w"$HOME" -m"$message"
			done < "$HOME/undeliverable_$DATE.lst"
			echo "finished adding notes to customer accounts"
		else
			echo "all customers could be emailed, no need to add a note on their accounts."
		fi
	else
		echo "'$HOME/notify_users_$DATE.lst' not created, nothing to do."
	fi
else
	echo "no non-visible titles have holds."
fi
# EOF
