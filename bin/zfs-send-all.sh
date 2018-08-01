#!/bin/bash
#
# Author    Leroy van Logchem
# Purpose   Replicates all filesystems in the for loop
#           (start interactively without delay use zfs-send-all.sh now)
# Trigger   To be added to the cron like:
#
# 0 1 * * *       [ -f /root/etc/roles/B2D ] && (/usr/local/cron/beheer/zfs-backup2disk/bin/zfs-send-all.sh)
#
#
# Assumption Hostname ends with number, e.g. 001 up to 014 ( used to staggered starting )
#

BASE_DIR=/usr/local/cron/beheer/zfs-backup2disk/bin

if [ ! -f /root/etc/roles/B2D ]; then
	echo "$0: DO NOT RUN THIS SCRIPT ON THE BACKUP"
	exit
fi

# Variable starting time based on hostname
# Every 900 seconds start a machine
#
HOSTNUMBER=$(hostname -s | tr -d '[a-z]')
DELAY=$(echo "${HOSTNUMBER} * 900 - 900"| bc)

# Waiting for my turn or start immediately :
if [ -z $1 ] ; then 
	sleep ${DELAY}
fi

for PROJECT in $(zfs list -p | grep "/tank/projects/" | sort -k 2 -n | awk '{print $NF}')
do
	${BASE_DIR}/zfs-send.sh -p $(basename ${PROJECT})
done
