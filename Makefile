####################################################
# Makefile for project cancellastcopydiscardholds.sh 
# Created: Mon Jun 22 15:51:12 MDT 2015
# Copyright (c) Edmonton Public Library Mon Jun 22 15:51:12 MDT 2015
#
#<one line to give the program's name and a brief idea of what it does.>
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
# Written by Andrew Nisbet at Edmonton Public Library
# Rev: 
#      0.1 - Added html message to repo for one-stop-editing. 
#      0.0 - Dev. 
####################################################
# Change comment below for appropriate server.
# PRODUCTION_SERVER=edpl.sirsidynix.net
PRODUCTION_SERVER=edpl.sirsidynix.net
TEST_SERVER=edpltest.sirsidynix.net
USER=sirsi
REMOTE=~/Unicorn/EPLwork/cronjobscripts/Notifycancelholds/
LOCAL=~/projects/notifycancelholds/
APP=notifycancelholds.sh
NOTICE=OnOrderCancelHoldNotice.html

test:
	scp ${LOCAL}${APP} ${USER}@${TEST_SERVER}:${REMOTE}
	scp ${LOCAL}${NOTICE} ${USER}@${TEST_SERVER}:${REMOTE}
	
production: test
	scp ${LOCAL}${APP} ${USER}@${PRODUCTION_SERVER}:${REMOTE}
	scp ${LOCAL}${NOTICE} ${USER}@${PRODUCTION_SERVER}:${REMOTE}

