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
#          0.1 - Basic infrastructure. 
#          0.0 - Dev.
# Dependencies: holdbot.pl, 
#               cancelholds.pl,
#
####################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
source /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################
VERSION=0.1
DATE=` date +%Y%m%d`
HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Notifycancelholds
BIN_CUSTOM=/s/sirsi/Unicorn/Bincustom
# Find and test for all our dependencies.
if [ ! -e $BIN_CUSTOM/cancelholds.pl ]
then
	echo "** error: key component '$BIN_CUSTOM/cancelholds.pl' missing!"
	exit 1;
fi
if [ ! -e $BIN_CUSTOM/holdbot.pl ]
then
	echo "** error: key component '$BIN_CUSTOM/holdbot.pl' missing!"
	exit 1;
fi
if [ ! -e $BIN_CUSTOM/mailerbot.pl ]
then
	echo "** error: key component '$BIN_CUSTOM/mailerbot.pl' missing!"
	exit 1;
fi
# API for selecting items with 0 visible copies:
# selcatalog -z"=0" | sort  | uniq | selcatalog -z"=0" -iC -h">0" | selhold -iC -j"ACTIVE" -a"N" -oUI 
# API for cancelled cancelled order:
# selitem -m"CANC_ORDER" -oC | sort  | uniq | selcatalog -z"=0" -iC -h">0" | selhold -iC -j"ACTIVE" -a"N" -oUI
selitem -m"CANC_ORDER" -oC | sort  | uniq | selcatalog -z"=0" -iC -h">0" | selhold -iC -j"ACTIVE" -a"N" -oC > $HOME/cat_keys_$DATE.lst
# cat $HOME/cat_keys_$DATE.lst | $BIN_CUSTOM/holdbot.pl -cU >$HOME/notify_users_$DATE.lst
cat $HOME/cat_keys_$DATE.lst | $BIN_CUSTOM/holdbot.pl -c >$HOME/notify_users_$DATE.lst
# $BIN_CUSTOM/mailerbot.pl -c $HOME/notify_users_$DATE.lst -n cancel_holds_message.txt -D
# EOF
