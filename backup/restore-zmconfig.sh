#!/bin/bash
# Script to restore Zoneminder config

backup="/tmp/Zoneminder-confbackup.tgz"

__checkdir() {

    if [[ ! -d  $1 ]]; then
        echo "Making directory $1."
        mkdir -p $1
    fi

}

tar xvfz ${backup} -C $(dirname ${backup})

rdir="$(dirname ${backup})/$(basename ${backup} .tgz)"
cp -f ${rdir}/env ../.env
source ../.env

__checkdir "${VOLDIR}/etc/ssmtp"
__checkdir "${VOLDIR}/etc/zm"
#__checkdir "${VOLDIR}/letsencrypt"

cp -f ${rdir}/ssmtp/* ${VOLDIR}/etc/ssmtp
cp -f ${rdir}/*.ini ${VOLDIR}/etc/zm
#cp -f ${rdir}/acme.json ${VOLDIR}/letsencrypt

echo "config files copied to volume ${VOLDIR}"
rm -rf ${rdir}
