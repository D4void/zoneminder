#!/bin/bash

set -e

#check if already configured or not
if [ -f /etc/configured ]; then
        echo 'container already configured'
	rm -rf /var/run/zm/*
        /sbin/zm.sh&
else
 #code that need to run only one time ....	

 #d4void: restore /etc/cron.d files to the volume
 cp -rf /etc/cron.d.bkp/. /etc/cron.d
 
 #trays to fix problem with https://github.com/QuantumObject/docker-zoneminder/issues/22
 chown www-data /dev/shm
 mkdir -p /var/run/zm
 chown www-data:www-data /var/run/zm

 # set the memory limit of php
 sed  -i "s|memory_limit = .*|memory_limit = ${PHP_MEMORY_LIMIT:-512M}|" /etc/php/7.4/apache2/php.ini

 #to fix problem with data.timezone that appear at 1.28.108 for some reason
 sed  -i "s|\;date.timezone =|date.timezone = \"${TZ:-America/New_York}\"|" /etc/php/7.4/apache2/php.ini
 echo ${TZ:-America/New_York} > /etc/timezone

 # copy from backup of /etc/zm if config files missing ..
 if [ ! -f /etc/zm/zm.conf ]; then
	mkdir -p /etc/zm
	cp -R /etc/backup_zm_conf/. /etc/zm
 fi

 #if ZM_SERVER_HOST variable is provided in container use it as is, if not left 02-multiserver.conf unchanged
 if [ -v ZM_SERVER_HOST ]; then sed -i "s|#ZM_SERVER_HOST=|ZM_SERVER_HOST=${ZM_SERVER_HOST}|" /etc/zm/conf.d/02-multiserver.conf; fi

 # relate to /etc/zm/zm.conf and db configuration
 sed  -i "s|ZM_DB_HOST=.*|ZM_DB_HOST=${ZM_DB_HOST}|" /etc/zm/zm.conf
 sed  -i "s|ZM_DB_NAME=.*|ZM_DB_NAME=${ZM_DB_NAME}|" /etc/zm/zm.conf
 sed  -i "s|ZM_DB_USER=.*|ZM_DB_USER=${ZM_DB_USER}|" /etc/zm/zm.conf
 sed  -i "s|ZM_DB_PASS=.*|ZM_DB_PASS=${ZM_DB_PASS}|" /etc/zm/zm.conf
 sed  -i "s|ZM_DB_PORT=.*|ZM_DB_PORT=${ZM_DB_PORT}|" /etc/zm/zm.conf
 grep -q ZM_DB_PORT /etc/zm/zm.conf || echo ZM_DB_PORT=$ZM_DB_PORT >> /etc/zm/zm.conf


 # Returns true once mysql can connect.
 mysql_ready() {
   mysqladmin ping --host=$ZM_DB_HOST --port=$ZM_DB_PORT --user=$ZM_DB_USER --password=$ZM_DB_PASS > /dev/null 2>&1
 }

 #check if Directory inside of /var/cache/zoneminder are present.
 if [ ! -d /var/cache/zoneminder/events ]; then
      mkdir -p /var/cache/zoneminder/{events,images,temp,cache}
      chown -R root:www-data /var/cache/zoneminder
      chmod -R 770 /var/cache/zoneminder
 fi

 chown -R root:www-data /etc/zm /var/log/zm
 chmod -R 770 /etc/zm /var/log/zm

 # Handle the zmeventnotification.ini file
 if [ -f /config/zmeventnotification.ini ]; then
    echo "Moving zmeventnotification.ini"
    if [ ! -d /var/cache/zoneminder/events ]; then
       mkdir -p /etc/zm/
    fi
    ln -sf /config/zmeventnotification.ini /etc/zm/zmeventnotification.ini
  fi

  # waiting for mysql
  while !(mysql_ready)
  do
    sleep 3
    echo "waiting for mysql ..."
  done

  # check if database is empty and fill it if necessary
  EMPTYDATABASE=$(mysql -u$ZM_DB_USER -p$ZM_DB_PASS --host=$ZM_DB_HOST --port=$ZM_DB_PORT --batch --skip-column-names -e "use ${ZM_DB_NAME} ; show tables;" | wc -l )
  # [ -f /var/cache/zoneminder/configured ]
  if [[ $EMPTYDATABASE != 0 ]]; then
        echo 'database already configured.'
	zmupdate.pl -nointeractive
        rm -rf /var/run/zm/*
	/sbin/zm.sh&
   else
        # if ZM_DB_NAME different that zm
        cp /usr/share/zoneminder/db/zm_create.sql /usr/share/zoneminder/db/zm_create.sql.backup
        sed -i "s|-- Host: localhost Database: .*|-- Host: localhost Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|-- Current Database: .*|-- Current Database: ${ZM_DB_NAME}|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ .*|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ \`${ZM_DB_NAME}\` \;|" /usr/share/zoneminder/db/zm_create.sql
        sed -i "s|USE .*|USE ${ZM_DB_NAME} \;|" /usr/share/zoneminder/db/zm_create.sql

        # prep the database for zoneminder
	mysql -u $ZM_DB_USER -p$ZM_DB_PASS -h $ZM_DB_HOST -P$ZM_DB_PORT $ZM_DB_NAME < /usr/share/zoneminder/db/zm_create.sql
        date > /var/cache/zoneminder/dbcreated

	#needed to fix problem with ubuntu ... and cron
        update-locale

        date > /var/cache/zoneminder/configured
        zmupdate.pl -nointeractive
        rm -rf /var/run/zm/*
        /sbin/zm.sh&
   fi
   date > /etc/configured
fi
