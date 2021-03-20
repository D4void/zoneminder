# Name of container: docker-zoneminder
# version of container: 0.6.4
# Based on quantumobject/docker-zoneminder
# D4void: adding /etc/ssmtp/ & /var/log/apache2 volumes
#         adding cambozola archive file (site down sometimes)
#
# docker build -t d4void/docker-zoneminder:1.34.23 .

FROM quantumobject/docker-baseimage:20.04
LABEL maintainer="d4void <d4void@m4he.fr>"

ENV TZ Europe/Paris
ENV ZM_DB_HOST db
ENV ZM_DB_NAME zm
ENV ZM_DB_USER zmuser
ENV ZM_DB_PASS zmpass
ENV ZM_DB_PORT 3306


# Update the container
# Installation of nesesary package/software for this containers...
RUN echo "deb http://ppa.launchpad.net/iconnor/zoneminder-1.34/ubuntu `cat /etc/container_environment/DISTRIB_CODENAME` main" >> /etc/apt/sources.list  \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 776FFB04 \
    && echo $TZ > /etc/timezone && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
          libvlc-dev  \
          libvlccore-dev\
          libapache2-mod-perl2 \
          vlc \
          ntp \
          dialog \
          ntpdate \
          ffmpeg \
		  ssmtp \
		  libyaml-perl \
		  libjson-perl \
		  make \
		  gcc \
		  net-tools \
		  build-essential \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/*

# to add apache2 deamon to runit
RUN mkdir -p /etc/service/apache2  /var/log/apache2 ; sync
COPY apache2.sh /etc/service/apache2/run
RUN chmod +x /etc/service/apache2/run \
    && cp /var/log/cron/config /var/log/apache2/ \
    && chown -R www-data /var/log/apache2

# to add zm deamon to runit
RUN mkdir -p /var/log/zm ; sync
COPY zm.sh /sbin/zm.sh
RUN chmod +x /sbin/zm.sh

##startup scripts
#Pre-config scrip that maybe need to be run one time only when the container run the first time .. using a flag to don't
#run it again ... use for conf for service ... when run the first time ...
RUN mkdir -p /etc/my_init.d
COPY startup.sh /etc/my_init.d/startup.sh
RUN chmod +x /etc/my_init.d/startup.sh

#pre-config scritp for different service that need to be run when container image is create
#maybe include additional software that need to be installed ... with some service running ... like example mysqld
COPY pre-conf.sh /sbin/pre-conf
RUN chmod +x /sbin/pre-conf ; sync \
    && /bin/bash -c /sbin/pre-conf \
    && rm /sbin/pre-conf

# d4void: adding cambozola archive file instead of curl
COPY cambozola-0.936.tar.gz /usr/src

RUN cd /usr/src \
        && tar -xzvf /usr/src/cambozola-0.936.tar.gz \
        && mv cambozola-0.936/dist/cambozola.jar /usr/share/zoneminder/www  \
        && rm /usr/src/cambozola-0.936.tar.gz \
        && rm -R /usr/src/cambozola-0.936

# add stuff or zmeventnotification.pl
RUN cd /usr/bin/ \
    && wget https://raw.githubusercontent.com/pliablepixels/zmeventserver/master/zmeventnotification.pl \
    && chmod a+x zmeventnotification.pl \
    && mkdir -p /var/lib/zmeventnotification/push/ \
    && chown -R www-data:www-data /var/lib/zmeventnotification
RUN perl -MCPAN -e "install Digest::SHA1"
RUN perl -MCPAN -e "install Crypt::MySQL"
RUN perl -MCPAN -e "install Config::IniFiles"
RUN perl -MCPAN -e "install Net::WebSocket::Server"
RUN perl -MCPAN -e "install LWP::Protocol::https"
RUN perl -MCPAN -e "install Net::MQTT::Simple"

# d4void: adding /etc/ssmtp/ & /var/log/apache2
VOLUME /var/cache/zoneminder /etc/zm /config /var/log/zm /etc/ssmtp /var/log/apache2
# to allow access from outside of the container  to the container service
# at that ports need to allow access from firewall if need to access it outside of the server.
EXPOSE 80 9000 6802

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
