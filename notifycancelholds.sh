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
#          0.5_10 - Added -i to run interactively. Default just run.
#          0.5_09 - Fix bug in output of opacsearchlink.pl and put unlinked titles on customer accounts.
#          0.5_08 - Add dynamic link handling through opacsearchlink.pl.
#          0.5_07 - Send message as HTML.
#          0.5_06 - Broadened  selection to just not select MISSING, LOST-ASSUM, and LOST items.
#          0.5_05 - Optimized selection criteria at selcatalog stage.
#          0.5_04 - Changes to non-emailed account message.
#          0.5_03 - Changes recommended by staff 
#                   July 22, 2015: hold Cancelled, no copies available – title 07/22/2015
#          0.5_02 - Added count to confirm message. 
#          0.5_01 - Updated to use new mask of pipe.pl. 
#          0.5 - Experimental use of search URL in holdbot.pl -s. 
#          0.4 - Widen the title string for better read-ability. 
#          0.3 - API selection re-work for MISSING and LOST-ASSUM. 
#          0.2 - Take a catalogue key as an argument. 
#          0.1 - Basic infrastructure. 
#          0.0 - Dev.
# Dependencies: holdbot.pl, 
#               cancelholds.pl,
#               pipe.pl,
#               mailerbot.pl
#               opacsearchlink.pl
#
####################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
source /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################
VERSION='0.5_10'
DATE=` date +%Y%m%d`
CANCEL_DATE=`date +%m/%d/%Y`
# If an item was charged out and became LOST-ASSUM, wait this amount of time before 
# cancelling the holds. The reason is; what if someone returns the item, but the holds
# have been cancelled? Turns out the lending period (21 days) + days as LOST-ASSUM = 51
# call it 60. After that it is extremely unlikely that the item will be recovered.
# LOST_ASSUM_CHARGE_DATE_THRESHOLD=`transdate -d-60` # 60 days ago.
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
if [ ! -e "$BIN_CUSTOM/opacsearchlink.pl" ]
then
	echo "** error: key component '$BIN_CUSTOM/opacsearchlink.pl' missing!"
	exit 1;
fi
cd $HOME
COUNT=0
if [ $# == 1 ]
then
	if [ "$1" != "-i" ]
	then
		echo "request to cancel holds on '$1'..."
		echo $1 > $HOME/cat_keys_$DATE.lst
	fi
else
	echo "Starting data collection..."
	################### Cancel all titles with zero visible items ######################
	# API for selecting items with 0 visible copies with the caveat that we don't want
	# missing items since they could be found in short order and by then we may have cancelled
	# many holds creating frustration and confusion for customers. We don't want LOST-ASSUM
	# that are younger than 60 days for the same reason. They eventually get checked out to discard.
	selcatalog -h">0" -z"=0" -oCh | selhold -iC -j"ACTIVE" -oIUp | selitem -iI -m'~LOST,MISSING,LOST-ASSUM' -oCSB | $BIN_CUSTOM/pipe.pl -m"c3:$DATE|#" > $HOME/cat_keys_$DATE.tmp$$
	# 
	if [ -s "$HOME/cat_keys_$DATE.tmp$$" ]
	then
		cat $HOME/cat_keys_$DATE.tmp$$ >>$HOME/cancelled_holds_data.log
		# Holdbot requires just cat keys on input so trim off the rest of the line.
		cat $HOME/cat_keys_$DATE.tmp$$ | $BIN_CUSTOM/pipe.pl -o"c0" >$HOME/cat_keys_$DATE.lst
		if [ -s "$HOME/cat_keys_$DATE.lst" ]
		then
			COUNT=`cat $HOME/cat_keys_$DATE.tmp$$ | wc -l`
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
# The script user can bail here if they just want to review the catalog keys.
echo -n "I have collected $COUNT catalogue keys. Continue cancelling holds on item with no visible copies? y[n]: "
if [ "$1" ]
then
	if [ "$1" == "-i" ]
	then
		read imsure
		if [ "$imsure" != "y" ]
		then
			echo "... it's ok to be cautious, exiting."
			exit 1
		fi
	fi
fi


if [ -s "$HOME/cat_keys_$DATE.lst" ]
then
	cat $HOME/cat_keys_$DATE.lst | $BIN_CUSTOM/holdbot.pl -cU >$HOME/no_link_notify_users_$DATE.lst 
	# Add me to the list to receive an email each time script is run.
	head -1  $HOME/no_link_notify_users_$DATE.lst | $BIN_CUSTOM/pipe.pl -m'c0:#####_019003992' >>$HOME/no_link_notify_users_$DATE.lst
	# Create title links for convient searching.
	cat $HOME/no_link_notify_users_$DATE.lst | $BIN_CUSTOM/opacsearchlink.pl -a -f'c1,c2,c3,c4,c5,c6,c7' >$HOME/notify_users_$DATE.lst 
	if [ -s "$HOME/notify_users_$DATE.lst" ]
	then
		$BIN_CUSTOM/mailerbot.pl -h -c"$HOME/notify_users_$DATE.lst" -n"$HOME/cancel_holds_message.html" >$HOME/undeliverable_$DATE.lst
		# Now use the undeliverable list and add a note on the customers account.
		# It will be adequate to use the first 15 characters of the title and a short message to the account.
		if [ -s "$HOME/undeliverable_$DATE.lst" ]
		then
			# Undeliverable customers need to have a different un-linked message on their account. 
			# Find the list of undeliverable and diff with $HOME/no_link_notify_users_$DATE.lst
			# diff.pl only outputs one match per comparison, but that's all that will fit in a comment on a customer account anyway.
			# Show us the users from undeliverable and no_link_notify, with the results pulled from the no_link_notify.
			echo "$HOME/no_link_notify_users_$DATE.lst and $HOME/undeliverable_$DATE.lst" | diff.pl -ec0 -fc0 >$HOME/no_link_add_note_$DATE.lst
			# IFS='' (or IFS=) prevents leading/trailing whitespace from being trimmed.
			# -r prevents backslash escapes from being interpreted.
			# || [[ -n $line ]] prevents the last line from being ignored if it 
			# doesn't end with a \n (since read returns a non-zero exit code 
			# when it encounters EOF).
			echo "reading in the undeliverable customers file..."
			while IFS='' read -r line || [[ -n $line ]]; do
				message=`echo "$line" | $BIN_CUSTOM/pipe.pl -o'c1' -m'c1:Hold cancelled\, no copies available -CMA- #######################_... '`$CANCEL_DATE
				customer=`echo "$line" | $BIN_CUSTOM/pipe.pl -o'c0'`
				echo "read '$message' for customer '$customer'"
				echo "$customer" | $BIN_CUSTOM/addnote.pl -q -m"$message"
			done < "$HOME/no_link_add_note_$DATE.lst"
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
