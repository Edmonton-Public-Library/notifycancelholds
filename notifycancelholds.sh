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
VERSION=0.2
DATE=` date +%Y%m%d`
CANCEL_DATE=`date +%Y.%m.%d`
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
	################### Cancel all titles with zero visible items ######################
	# API for selecting items with 0 visible copies:
	# selcatalog -z"=0" | sort  | uniq | selcatalog -z"=0" -iC -h">0" | selhold -iC -j"ACTIVE" -a"N" -oUI 
	################### Cancelled Orders #####################
	# API for cancelled cancelled order:
	selitem -m"CANC_ORDER" -oC | sort  | uniq | selcatalog -z"=0" -iC -h">0" | selhold -iC -j"ACTIVE" -a"N" -oC > $HOME/cat_keys_$DATE.lst
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
				message=`echo "$line" | pipe.pl -o'c1' -m'c1:Cancelled hold on @@@@@@@@@@@@@@@... -'`$CANCEL_DATE
				customer=`echo "$line" | pipe.pl -o'c0'`
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
	echo "no cancelled orders have holds."
fi
# EOF
