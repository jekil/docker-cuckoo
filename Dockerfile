############################################################
# Cuckoo Sandbox Dockerfile
# https://cuckoosandbox.org
############################################################
#
# Copyright (C) 2016 Alessandro Tanasi
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Set the base image to use to Ubuntu.
FROM ubuntu:16.04
MAINTAINER Alessandro Tanasi <alessandro@tanasi.it>

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /tmp/docker/build/

# Cuckoo user.
RUN groupadd cuckoo
RUN useradd --create-home --home-dir /home/cuckoo -g cuckoo cuckoo

# Copy requirements files.
COPY files/*.txt /tmp/

# Setup basic deps.
RUN apt-get update
RUN xargs apt-get install -y < /tmp/deb-packages.txt
RUN rm /tmp/deb-packages.txt
RUN pip install --upgrade -r /tmp/pypi-packages.txt
RUN rm /tmp/pypi-packages.txt

# Setup Yara.
RUN wget https://github.com/plusvic/yara/archive/v3.4.0.tar.gz
RUN tar xzvf *.tar.gz
RUN cd yara-*  && \
    ./bootstrap.sh && \
    ./configure --with-crypto --enable-cuckoo --enable-magic  && \
    make && \
    make install && \
    cd yara-python && \
    python setup.py build && \
    python setup.py install && \
    ldconfig 

# Setup ssdeep.
RUN wget http://downloads.sourceforge.net/project/ssdeep/ssdeep-2.13/ssdeep-2.13.tar.gz
RUN tar xzvf ssdeep-2.13.tar.gz
RUN cd ssdeep-* && \
    ./configure  && \
    make && \
    make install

# Setup pydeep (the latest pypi is an old 0.2).
RUN wget https://github.com/kbandla/pydeep/archive/0.4.tar.gz
RUN tar xzvf 0.4.tar.gz
RUN cd pydeep-* && \
    python setup.py build && \
    python setup.py install 

# Setup Volatility.
RUN wget https://github.com/volatilityfoundation/volatility/archive/2.5.tar.gz
RUN tar xzvf 2.5.tar.gz
RUN cd volatility-*  && \
    python setup.py build && \
    python setup.py install

# Setup Cuckoo.
RUN cd /home/cuckoo && \
    wget https://downloads.cuckoosandbox.org/cuckoo-current.tar.gz && \
    tar xzf *.tar.gz  && \
    rm *.tar.gz
RUN cd /home/cuckoo/cuckoo && \
    pip install --upgrade -r requirements.txt && \
    rm -rf data/monitor/latest && \
    ./utils/community.py -wafb 2.0
RUN rm /home/cuckoo/cuckoo/conf/cuckoo.conf && rm /home/cuckoo/cuckoo/conf/reporting.conf
COPY conf/supervisord.conf /etc/supervisor/conf.d/cuckoo.conf
COPY conf/cuckoo/*.conf /home/cuckoo/cuckoo/conf/
RUN chown -R cuckoo /home/cuckoo

# Allow tcpdump to dump packet captures when executed as a normal user.
USER root
RUN setcap cap_net_raw,cap_net_admin=eip `which tcpdump`

# Cleanup.
RUN rm -rf /tmp/docker/build/*
RUN apt-get clean

EXPOSE 8000 2042 8090
VOLUME ["/home/cuckoo/cuckoo"]
CMD ["/usr/bin/supervisord"]
