#!/bin/bash
clear
sleep 5
echo
echo "DEMO Beschrijving: Exacte replicatie van een P-schijf project naar Back-up locatie"
echo
sleep 3
echo -n "Replicatie van project "
zfsdf | grep 1207919-dam-live
sleep 2
echo
echo "Het aantal bestanden in dit filesysteem is NIET van invloed op de verzending"
echo
sleep 2
df -i /tank/projects/1207919-dam-live
echo
echo "In dit geval is het aantal bestanden redelijk hoog: honderachtendertig duizend bestanden."
sleep 3
echo
echo "Veiligstellen naar de backup-to-disk uitwijk locatie:"
sleep 1
echo
/root/persistent/zfs-backup2disk/bin/zfs-send-initial.sh -p 1207919-dam-live
echo
echo "RESULTATEN:"
sleep 1
echo "-- Alle bestanden en bijbehorende attributen zijn veilig overgebracht"
sleep 2
echo "-- De doorloopsnelheid is niet afhankelijk van het aantal bestanden of folders"
sleep 2
echo "-- Communicatie is versleuteld en gecomprimeerd"
echo
echo
echo
echo
sleep 10
