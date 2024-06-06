# Name of container: d4void/docker-zoneminder
# Based on old project quantumobject/docker-zoneminder, now gone from Github
#
# Use phusion/baseimage as base image.
# https://github.com/phusion/baseimage-docker
#
# Build a v1.36 Zoneminder image including zmeventserver (OpenCV 4.5 installed with pip so no GPU support)
# https://github.com/ZoneMinder/zoneminder 
# https://github.com/ZoneMinder/zmeventnotification
#
#
# docker build -t d4void/docker-zoneminder:1.36.33 .

###
# Image to build missing perl dependencies for use in final container
###

FROM phusion/baseimage:jammy-1.0.4 as perlbuild

WORKDIR /usr/src
RUN apt-get update && apt-get install -y -q --no-install-recommends \
        tzdata \
        perl \
        make \
        gcc \
        net-tools \
        build-essential \
        dh-make-perl \
        libgit-repository-perl \
        libprotocol-websocket-perl \
        apt-file \
    && apt-get clean
RUN apt-file update \
    && dh-make-perl --build --cpan Net::WebSocket::Server \
    && dh-make-perl --build --cpan Net::MQTT::Simple

###
# Now build the Zoneminder final image
###

FROM phusion/baseimage:jammy-1.0.4

ENV ZM_DB_HOST db
ENV ZM_DB_NAME zm
ENV ZM_DB_USER zmuser
ENV ZM_DB_PASS zmpass
ENV ZM_DB_PORT 3306

COPY --from=perlbuild /usr/src/*.deb /usr/src/

# Update the container
# Installation of necessary packages for this container...
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get install -y -q --no-install-recommends \
        tzdata \
        libvlc-dev  \
        libvlccore-dev\
        apache2 \
        libapache2-mod-perl2 \
        vlc \
        dialog \
        ntpdate \
        ffmpeg \
        ssmtp \
        sudo \
        wget \
        # Perl modules needed for zmeventserver
        libyaml-perl \
        libjson-perl \
        libconfig-inifiles-perl \
        liblwp-protocol-https-perl \
        libprotocol-websocket-perl \
        # Other dependencies for event zmeventserver
        python3-pip \
        libgeos-dev \
        gifsicle \
    && dpkg -i /usr/src/*.deb \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/* \
    &&  mkdir -p /etc/service/apache2 /var/log/apache2 /var/log/zm /etc/my_init.d

# copying scripts
COPY *.sh /usr/src/

# copying ssmtp config
COPY etc_ssmtp/ /etc/template_ssmtp/

# Moving scripts to correct locations and setting permissions
RUN mv /usr/src/apache2.sh /etc/service/apache2/run \
    && mv /usr/src/zm.sh /sbin/zm.sh \
    && mv /usr/src/startup.sh /etc/my_init.d/startup.sh \
    && chmod +x /etc/service/apache2/run \
    && chown -R www-data /var/log/apache2 \
    && chmod +x /sbin/zm.sh \
    && chmod +x /etc/my_init.d/startup.sh

# Install python requirements for zmeventserver
COPY requirements.txt /usr/src/requirements.txt

RUN pip3 install --no-cache-dir -r /usr/src/requirements.txt

# Install zoneminder
RUN add-apt-repository ppa:iconnor/zoneminder-1.36 \
    && apt-get update \
    && apt-get install -y -q --no-install-recommends libapache2-mod-php php-gd zoneminder \
    && echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf \
    && ln -s /etc/apache2/conf-available/fqdn.conf /etc/apache2/conf-enabled/fqdn.conf \
    && sed -i "s|KeepAliveTimeout 5|KeepAliveTimeout 1|g" /etc/apache2/apache2.conf \
    && sed -i "s|Timeout 300|Timeout 60|g" /etc/apache2/apache2.conf \
    && sed -i "s|ServerSignature On|ServerSignature Off|g" /etc/apache2/conf-available/security.conf \
    && sed -i "s|ServerTokens OS|ServerTokens Prod|g" /etc/apache2/conf-available/security.conf \
    && echo "LogFormat \"%{X-Forwarded-For}i %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" proxy" >> /etc/apache2/apache2.conf \
    && echo "CustomLog \${APACHE_LOG_DIR}/zoneminder_access.log proxy" >> /etc/apache2/conf-available/zoneminder.conf \
    && a2disconf other-vhosts-access-log \
    && a2enmod cgi rewrite \
    && a2enconf zoneminder \
    && adduser www-data video \
    && chown -R www-data:www-data /usr/share/zoneminder/ \
    && mkdir -p /var/run/zm \
    && chown www-data:www-data /var/run/zm \
    && chown www-data /dev/shm \
    && mkdir /etc/backup_cron.d \
    && cp /etc/cron.d/* /etc/backup_cron.d \
    && rm -R /var/www/html \
    && rm /etc/apache2/sites-enabled/000-default.conf \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* \
    && rm -rf /var/lib/apt/lists/*

# Install zmeventserver
ENV ZMEVENT_VERSION v6.1.29
RUN mkdir /usr/src/zmevent \
    && cd /usr/src/zmevent \
    && wget -qO- https://github.com/ZoneMinder/zmeventnotification/archive/${ZMEVENT_VERSION}.tar.gz |tar -xzv --strip 1 \
    && ./install.sh --install-config --install-es --install-hook --no-interactive --no-download-models --no-pysudo \
    && mkdir -p /etc/backup_zm_conf \
    && cp -R /etc/zm/* /etc/backup_zm_conf/

VOLUME /var/cache/zoneminder /etc/zm /var/log/zm /etc/ssmtp /var/log/apache2 \
       /var/lib/zmeventnotification/models /var/lib/zmeventnotification/images

EXPOSE 80 9000 6802

# Use baseimage's init system.
CMD ["/sbin/my_init"]
