# Script to restore Zoneminder config
#!/bin/bash

source .env

backup="/tmp/Zoneminder-confbackup.tgz"

__checkdir() {

    if [[ ! -d  $1 ]]; then
        "Making directory $1."
        mkdir -p $1
    fi

}

__checkdir "${VOLDIR}/etc/ssmtp"
__checkdir "${VOLDIR}/etc/zm"
__checkdir "${VOLDIR}/etc/traefik"
__checkdir "${VOLDIR}/letsencrypt"

tar xvfz ${backup} -C $(dirname ${backup})

cd $(dirname ${backup})/$(basename ${backup} .tgz)
cp -f ssmtp/* ${VOLDIR}/etc/ssmtp
cp -f *.ini ${VOLDIR}/etc/zm
cp -f traefik.toml ${VOLDIR}/etc/traefik
cp -f acme.json ${VOLDIR}/letsencrypt

echo "config files copied to volume ${VOLDIR}"
rm -rf $(dirname ${backup})/$(basename ${backup} .tgz)