#!/bin/bash
# Script to restore Zoneminder data

source ../.env
backup=$1

echo -n "Will replace ${VOLDIR}/var. Sure ? (y/n)> "
read rep
if [ $rep != 'y' ]; then
    exit 0
fi

tar xvfz ${backup} -C ${VOLDIR}

cat <<INFO
*****
To restore bdd:
source .env
docker compose up zm-db -d
docker compose exec -T zm-db mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < ${VOLDIR}/var/zm-dump-....sql
docker compose stop zm-db

*****

INFO
