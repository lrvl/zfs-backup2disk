#!/bin/bash
#
# Purpose	Send incremental datastream using two snapshots to remote replica
# Author	Leroy van Logchem (reusing parts of scripts by Jan Mostert)
# Project	Herziening backup strategie "Back-up to Disk"
# Date		1 aug 2018
#
# Usage	example:
#
#		zfs-send-incr.sh -p filesystemname
# 
# Prerequisites:
#  - SSH Passwordless Login to remote replica
#  - Daily snapshots are created *before* running the incremental sync
#  - Daily snapshots naming example: 2018-05-23_00.00.00--60d
#
# Notes:
#  - Initial sending will be sorted by size (smallest first)
#  - using: zfs list -p | grep "/tank/projects/" | sort -k 2 -n | head
#

SCRIPT_NAME=zfs-send
BASE_DIR=/usr/local/cron/beheer/zfs-backup2disk
BIN_DIR=${BASE_DIR}/bin
ETC_DIR=${BASE_DIR}/etc
LOG_DIR=${BASE_DIR}/log
TMP_DIR=${BASE_DIR}/tmp

LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}.log
ERR_FILE=${TMP_DIR}/${SCRIPT_NAME}.err
ACC_FILE=${ETC_DIR}/${SCRIPT_NAME}.dat

readonly tfrmt='%Y-%m-%d_00.00.00--60d'
SNAPSHOT_NAME_OLD=$(gdate "+$tfrmt" --date="1 days ago")
SNAPSHOT_NAME=$(gdate "+$tfrmt")
ZFS_SEND_ARG_FULL="send -R -p"
ZFS_SEND_ARG_INCR="send -R -p -I"
PREFIX_SOURCE="tank/projects"
PREFIX_TARGET="tank/projects"
SSH_OPTS="-o StrictHostKeyChecking=no -c aes128-gcm@openssh.com"
LOG_TIMESTAMP=$(date +"%F %H:%M:%S")
echo "START ${LOG_TIMESTAMP}" >> ${LOG_FILE}
echo " Used version: ${VERSION} (${VERSIONDATE})" >> ${LOG_FILE}

if [ "$*" != "" ]
then
    echo " -> Called with options: \"$*\"" >> ${LOG_FILE}
fi

PID_FILE="${TMP_DIR}/pidfile"
if [ -f "${PID_FILE}" ] && kill -0 `cat ${PID_FILE}` 2>/dev/null; then
	echo " ERROR: Still running"
	echo " ERROR: Still running, see pidfile ${PIDFILE}" >> ${LOG_FILE}
    exit 1
fi
echo $$ > ${PID_FILE}

function Check_Host ()
#===================================================================
#
# Function Check_Host controleert of een gegeven host online is
#
#===================================================================
{
    HOST2CHECK=$1
    RETVAL=0
    host ${HOST2CHECK} > /dev/null
    if [ $? -ne 0 ]; then
        RETVAL=1
    else
        ping -q -s 1024 -c 1 ${HOST2CHECK} > /dev/null
        if [ $? -ne 0 ]; then
            RETVAL=2
        else
            nc -z ${HOST2CHECK} 22 > /dev/null
            if [ $? -ne 0 ]; then
                RETVAL=3
            fi
        fi
    fi
    return $RETVAL
}

#
# ... Haal eventuele opties op
#
while [ $# -gt 0 ]
do
    case $1 in
        "-p")   shift; PROJECT="$1" ;;
        *)  echo " ERROR: Unknown argument or option used: $1" >> ${LOG_FILE}
            ((NERROR++))
            if [ ${NERROR} -eq 1 ]; then
                echo " "
                echo -e "\nUsage: zfs-send-initial.sh options"
                echo " "
                echo "Options:"
                echo "-p  Project path, short (ie 1209442-swivt)"
                echo " "
            fi
    esac
    shift
done

#
# Check to see the filesystem exists
#
if [ ! -d "/$PREFIX_SOURCE/$PROJECT" ]; then
	echo " ERROR: Project $PROJECT does not exist" >> ${LOG_FILE}
fi
#
# Check to see todays snapshot is available 
#
if zfs list -r -t snapshot -H -o name -s name ${PREFIX_SOURCE}/${PROJECT} | grep -q ${SNAPSHOT_NAME}; then
	echo " OK: Project $PROJECT and has todays snapshot!" >> ${LOG_FILE}
else
	echo " ERROR: Project $PROJECT exist but doesnt have todays snapshot!" >> ${LOG_FILE}
	exit
fi

TARGET=$(hostname -s | sed "s/storage/backup/")

echo -e "Check host \"${TARGET}\": \c"
Check_Host "${TARGET}"
RETVAL=$?

case ${RETVAL} in
	0)  echo "Check host ${TARGET} Ok!"
            echo "Check host ${TARGET} Ok!" >> ${LOG_FILE} ;;
        1)  echo "Name does not exist!"
            echo "Name does not exist!" >> ${LOG_FILE};;
        2)  echo "Cannot ping host!"
            echo "Cannot ping host!" >> ${LOG_FILE};;
        3)  echo "Cannot connect host!"
            echo "Cannot connect host!" >> ${LOG_FILE};;
esac

if ssh ${SSH_OPTS} ${TARGET} "[ -d /${PREFIX_TARGET}/${PROJECT} ]"; then
	#
	# Send INCREMENTAL
	#
	LOG_TIMESTAMP=$(date +"%F %H:%M:%S")
	ZFSLOG_TIMESTAMP=$(date +"%Y%m%d-%Hh%Mm")
	REMOTE_SNAP=$(ssh ${SSH_OPTS} ${TARGET} "ls -1 /${PREFIX_TARGET}/${PROJECT}/.zfs/snapshot/ | grep "60d$" | sort -r | head -1")
	if [ "${REMOTE_SNAP}" == "${SNAPSHOT_NAME}" ]; then
		echo "${LOG_TIMESTAMP} ${PROJECT} already exists at backup target, and snapshot is current. Do nothing." >> ${LOG_FILE}
	else
		echo "${LOG_TIMESTAMP} ${PROJECT} already exists at backup target, sending INCREMENTAL" >> ${LOG_FILE}
		echo "STARTING INCR zfs ${ZFS_SEND_ARG_INCR} "${PREFIX_SOURCE}/${PROJECT}@${REMOTE_SNAP}" "${PREFIX_SOURCE}/${PROJECT}@${SNAPSHOT_NAME}" | ssh ${SSH_OPTS} $TARGET zfs recv -F -v ${PREFIX_TARGET}/${PROJECT} 2>&1 | tee -a ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-incr.log" | tee -a ${LOG_FILE} ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-incr.log
		zfs ${ZFS_SEND_ARG_INCR} "${PREFIX_SOURCE}/${PROJECT}@${REMOTE_SNAP}" "${PREFIX_SOURCE}/${PROJECT}@${SNAPSHOT_NAME}" | ssh ${SSH_OPTS} $TARGET zfs recv -F -v ${PREFIX_TARGET}/${PROJECT} 2>&1 | tee -a ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-incr.log
	fi

else

	#
	# Send FULL
	#
	echo "${LOG_TIMESTAMP} ${PROJECT} doesnt exists at backup target, sending FULL" >> ${LOG_FILE}
	echo "STARTING FULL zfs ${ZFS_SEND_ARG_FULL} "${PREFIX_SOURCE}/${PROJECT}@${SNAPSHOT_NAME}" | ssh ${SSH_OPTS} $TARGET zfs recv -F -v ${PREFIX_TARGET}/${PROJECT} 2>&1 | tee -a ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-full.log" | tee -a ${LOG_FILE} ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-full.log
	zfs ${ZFS_SEND_ARG_FULL} "${PREFIX_SOURCE}/${PROJECT}@${SNAPSHOT_NAME}" | ssh ${SSH_OPTS} $TARGET zfs recv -F -v ${PREFIX_TARGET}/${PROJECT} 2>&1 | tee -a ${LOG_DIR}/${PROJECT}-${ZFSLOG_TIMESTAMP}-full.log
fi

LOG_TIMESTAMP=$(date +"%F %H:%M:%S")
echo "END ${LOG_TIMESTAMP}" >> ${LOG_FILE}
