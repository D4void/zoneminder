#!/bin/bash
# Script executed at container startup
# When zm container is launched for the first time, many things need to be done

# Returns true once mysql can connect.
mysql_ready() {
        mysqladmin ping --host=$ZM_DB_HOST --port=$ZM_DB_PORT --user=$ZM_DB_USER --password=$ZM_DB_PASS > /dev/null 2>&1
}

set -e
phpver="8.1"

# set timezone of the container
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# php.ini timezone
awk '$0="date.timezone = "$0' /etc/timezone >> /etc/php/$phpver/apache2/php.ini

# PHP settings
sed  -i "s|memory_limit = .*|memory_limit = ${PHP_MEMORY_LIMIT:-2048M}|" /etc/php/$phpver/apache2/php.ini
sed  -i "s|max_execution_time = .*|max_execution_time = ${PHP_MAX_EXECUTION_TIME:-600}|" /etc/php/$phpver/apache2/php.ini
sed  -i "s|max_input_time = .*|max_input_time = ${PHP_MAX_INPUT_TIME:-600}|" /etc/php/$phpver/apache2/php.ini
sed  -i "s|;max_input_vars = .*|max_input_vars = ${PHP_MAX_INPUT_VARIABLES:-3000}|" /etc/php/$phpver/apache2/php.ini


# check if container already configured or not. First time container launch ...
if [ ! -f /var/cache/zoneminder/.configured ]; then

        echo "First time container is running"

        # copy ssmtp config files to the volume
        cp -rf /etc/template_ssmtp/* /etc/ssmtp

        # restore /etc/cron.d files to the volume
        cp -f /etc/backup_cron.d/* /etc/cron.d
 
        # restore zm config files to the volume
        if [ ! -f /etc/zm/zm.conf ]; then
                mkdir -p /etc/zm
        	cp -Rf /etc/backup_zm_conf/* /etc/zm
                chmod o+r /etc/zm/zm.conf
        fi

        #if ZM_SERVER_HOST variable is provided in container use it as is, if not left 02-multiserver.conf unchanged
        if [ -v ZM_SERVER_HOST ]; then sed -i "s|#ZM_SERVER_HOST=|ZM_SERVER_HOST=${ZM_SERVER_HOST}|" /etc/zm/conf.d/02-multiserver.conf; fi
        #if ZM_SERVER_HOST variable is provided in container use it as is, if not left 02-multiserver.conf unchanged
        if [ -v ZM_SERVER_HOST ]; then sed -i "s|#ZM_SERVER_HOST=|ZM_SERVER_HOST=${ZM_SERVER_HOST}|" /etc/zm/conf.d/02-multiserver.conf; fi

        # db configuration in zm.conf
        sed  -i "s|ZM_DB_HOST=.*|ZM_DB_HOST=${ZM_DB_HOST}|" /etc/zm/zm.conf
        sed  -i "s|ZM_DB_NAME=.*|ZM_DB_NAME=${ZM_DB_NAME}|" /etc/zm/zm.conf
        sed  -i "s|ZM_DB_USER=.*|ZM_DB_USER=${ZM_DB_USER}|" /etc/zm/zm.conf
        sed  -i "s|ZM_DB_PASS=.*|ZM_DB_PASS=${ZM_DB_PASS}|" /etc/zm/zm.conf
        sed  -i "s|ZM_DB_PORT=.*|ZM_DB_PORT=${ZM_DB_PORT}|" /etc/zm/zm.conf

        # check if Directories inside of /var/cache/zoneminder are present.
        if [ ! -d /var/cache/zoneminder/events ]; then
                mkdir -p /var/cache/zoneminder/{events,images,temp,cache}
                chown -R root:www-data /var/cache/zoneminder
                chmod -R 775 /var/cache/zoneminder
        fi

        chown -R root:www-data /var/log/zm
        chmod -R 775 /var/log/zm
        chown -R www-data:www-data /var/lib/zmeventnotification/

        # Eventserver / Machine Learning models download
        # set env variables in compose file
        # INSTALL_YOLOV3=no INSTALL_TINYYOLOV3=no INSTALL_YOLOV4=yes INSTALL_TINYYOLOV4=no INSTALL_CORAL_EDGETPU=no
        echo "Downloading Machine Learning models"
        cd /usr/src/zmevent/
        ./install.sh --no-install-es --install-hook --no-install-config --no-hook-config-upgrade --no-pysudo --no-interactive > /dev/null 2>&1

        # waiting for Mariadb
        while !(mysql_ready)
        do
                sleep 3
                echo "Waiting for Mariadb..."
        done

        # init database if empty
        EMPTYDATABASE=$(mysql -u$ZM_DB_USER -p$ZM_DB_PASS --host=$ZM_DB_HOST --port=$ZM_DB_PORT --batch --skip-column-names -e "use ${ZM_DB_NAME} ; show tables;" | wc -l )
        if [[ $EMPTYDATABASE == 0 ]]; then
                cp /usr/share/zoneminder/db/zm_create.sql /etc/mysql/conf.d
                sed -i "s|-- Host: localhost Database: .*|-- Host: localhost Database: ${ZM_DB_NAME}|" /etc/mysql/conf.d/zm_create.sql
                sed -i "s|-- Current Database: .*|-- Current Database: ${ZM_DB_NAME}|" /etc/mysql/conf.d/zm_create.sql
                sed -i "s|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ .*|CREATE DATABASE \/\*\!32312 IF NOT EXISTS\*\/ \`${ZM_DB_NAME}\` \;|" /etc/mysql/conf.d/zm_create.sql
                sed -i "s|USE .*|USE ${ZM_DB_NAME} \;|" /etc/mysql/conf.d/zm_create.sql

                # prep the database for zoneminder
        	mysql -u $ZM_DB_USER -p$ZM_DB_PASS -h $ZM_DB_HOST -P$ZM_DB_PORT $ZM_DB_NAME < /etc/mysql/conf.d/zm_create.sql
                date > /var/cache/zoneminder/.dbcreated
        fi

        date > /var/cache/zoneminder/.configured
fi

# waiting for Mariadb
while !(mysql_ready)
do
        sleep 3
        echo "Waiting for Mariadb..."
done
# check db update
zmupdate.pl -nointeractive
# zm launch
rm -rf /var/run/zm/*
/sbin/zm.sh&
