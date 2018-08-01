#!/bin/bash
#
# Description		Create partitions for RAIDZ1 ZPOOL, low 5.8% loss
# Project		Herziening Backup
# Author		Leroy van Logchem
# Date			5 june 2018
#

DISK='da2'
NUMBER_OF_PARTS=20

read -p "Are you sure to destroy the contents of disk ${DISK} (y/n)?" choice
case "$choice" in 
  y|Y ) echo "ok";;
  n|N ) exit;;
  * ) echo "invalid";;
esac

DISK_BYTES=$(diskinfo -v ${DISK} | grep bytes | awk '{print $1}')
echo "Disk ${DISK} can contain ${DISK_BYTES} bytes"
PART_BYTES=$(echo "${DISK_BYTES} / ${NUMBER_OF_PARTS}" | bc)
PART_KB=$(echo "(${PART_BYTES} / 1024) - 2" | bc) # Bytes to KB minus 2KB for GEOM
echo "Each of the ${NUMBER_OF_PARTS} partitions will contain ${PART_KB} KB"
sleep 1
echo "Removing any partition data"
gpart destroy -F ${DISK}
sleep 1
echo "Creating partitions"
gpart create -s gpt ${DISK} 
for partition in $(seq -w 1 ${NUMBER_OF_PARTS})
do
	echo "part ${partition}"
	gpart add -s ${PART_KB}K -t freebsd-zfs -l zfs-disk${partition} ${DISK}
done

DEVS=$(ls -1 /dev/gpt/zfs-disk* | paste -s -d " " -)
echo "Creating zpool using raid with devices ${DEVS}"
sysctl -w vfs.zfs.vdev.trim_on_init=0
zpool create tank raidz ${DEVS}
zfs set compression=lz4 tank
zfs set aclmode=passthrough tank
zfs set aclinherit=passthrough tank
zfs create -o casesensitivity=mixed tank/projects
sysctl -w vfs.zfs.vdev.trim_on_init=1
