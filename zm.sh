#!/bin/bash
### In zm.sh (make sure this file is chmod +x):
# `chpst -u root` runs the given command as the user `root`.
# If you omit that part, the command will be run as root.

sleep 7s
exec chpst -u root /usr/bin/zmpkg.pl start >>/var/log/zm/zm.log 2>&1
