#!/bin/bash
# Script to backup Zoneminder data

source ../.env

docker compose exec zm-db mysqldump -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} > ${VOLDIR}/var/zm-dump-$(date +%F_%Hh%Mm%S).sql

file="/tmp/Zoneminder-databackup-$(date +%F_%Hh%Mm%S).tgz"
tar cvfz ${file} -C ${VOLDIR} var/
chmod ugo+r ${file}

rm -f ${VOLDIR}/var/*.sql
