#!/bin/bash
echo "Starting Zoneminder..."
exec /sbin/setuser www-data /usr/bin/zmpkg.pl start >> /var/log/zm/zm.log 2>&1
