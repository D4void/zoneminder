#!/bin/sh
source /etc/apache2/envvars
echo "Starting Apache..."
exec /sbin/setuser root /usr/sbin/apache2ctl -D FOREGROUND 2>&1
