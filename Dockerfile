# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START cloudrun_fuse_dockerfile]
# Use the official lightweight Python image.
# https://hub.docker.com/_/python
ARG IMAGE_VERSION=9.0-jdk11-openjdk-slim-buster
ARG JAVA_HOME=/usr/local/openjdk-11

FROM tomcat:$IMAGE_VERSION

# Argumentos docker-geoserver
LABEL maintainer="Tim Sutton<tim@linfiniti.com>"
ARG GS_VERSION=2.20.1
ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_BASE_URL=https://liquidtelecom.dl.sourceforge.net
ARG DOWNLOAD_ALL_STABLE_EXTENSIONS=1
ARG DOWNLOAD_ALL_COMMUNITY_EXTENSIONS=1
ARG GEOSERVER_UID=1000
ARG GEOSERVER_GID=10001
ARG USER=geoserveruser
ARG GROUP_NAME=geoserverusers
ARG HTTPS_PORT=8443

#Install extra fonts to use with sld font markers
RUN apt-get -y update; apt-get -y --no-install-recommends install fonts-cantarell lmodern ttf-aenigma \
    ttf-georgewilliams ttf-bitstream-vera ttf-sjfonts tv-fonts  libapr1-dev libssl-dev  \
    gdal-bin libgdal-java wget zip unzip curl xsltproc certbot  cabextract gettext postgresql-client figlet

RUN set -e \
    export DEBIAN_FRONTEND=noninteractive \
    dpkg-divert --local --rename --add /sbin/initctl \
    && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    JAVA_HOME=${JAVA_HOME} \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/local/gdal_data \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/gdal_native_libs:/usr/local/tomcat/native-jni-lib:/usr/lib/jni:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    CERT_DIR=/etc/certs \
    RANDFILE=/etc/certs/.rnd \
    FONTS_DIR=/opt/fonts \
    GEOSERVER_HOME=/geoserver \
    EXTRA_CONFIG_DIR=/settings

# Install system dependencies
RUN set -e; \
    apt-get update -y && apt-get install -y \
    tini \
    gnupg \
    curl \
    lsb-release; \
    gcsFuseRepo=gcsfuse-`lsb_release -c -s`; \
    echo "deb http://packages.cloud.google.com/apt $gcsFuseRepo main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list; \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add -; \
    apt-get update; \
    apt-get install -y gcsfuse \
    && apt-get clean

# Set fallback mount directory
ENV MNT_DIR /mnt/gcs

# Copy local code to the container image.
# ENV APP_HOME /app
# WORKDIR $APP_HOME
# COPY . ./

# Workdir 
WORKDIR /scripts
RUN groupadd -r ${GROUP_NAME} -g ${GEOSERVER_GID} && \
    useradd -m -d /home/${USER}/ -u ${GEOSERVER_UID} --gid ${GEOSERVER_GID} -s /bin/bash -G ${GROUP_NAME} ${USER}
RUN mkdir -p  ${GEOSERVER_DATA_DIR} ${CERT_DIR} ${FOOTPRINTS_DATA_DIR} ${FONTS_DIR} \
             ${GEOWEBCACHE_CACHE_DIR} ${GEOSERVER_HOME} ${EXTRA_CONFIG_DIR} /community_plugins /stable_plugins \
           /plugins /geo_data

# Install production dependencies.
# RUN pip install -r requirements.txt

# Ensure the script is executable
RUN chmod +x /app/gcsfuse_run.sh

# Use tini to manage zombie processes and signal forwarding
# https://github.com/krallin/tini
# ENTRYPOINT ["/usr/bin/tini", "--"] 

# Pass the startup script as arguments to Tini
CMD ["/app/gcsfuse_run.sh"]
# [END cloudrun_fuse_dockerfile]