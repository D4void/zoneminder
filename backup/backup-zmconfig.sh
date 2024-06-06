#!/bin/bash
# Script to backup Zoneminder config

source ../.env

backupdir="/tmp/Zoneminder-confbackup"
mkdir ${backupdir}

cp -f ../.env ${backupdir}/env
cp -rf ${VOLDIR}/etc/ssmtp/ ${backupdir}
cp -f ${VOLDIR}/etc/zm/*.ini ${backupdir}
#cp -f ${VOLDIR}/letsencrypt/acme.json ${backupdir}

tar cvfz ${backupdir}.tgz -C $(dirname ${backupdir}) $(basename ${backupdir})
chmod ugo+r ${backupdir}.tgz
rm -rf ${backupdir}