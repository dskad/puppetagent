FROM centos:7

MAINTAINER Dan Skadra <dskadra@gmail.com>

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
# RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# ENV LANG en_US.utf8

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.2.*"
# ARG PUPPETAGENT_VERSION="1.2.6"

# Persist variables into child images
ENV PUPPETENV=production \
    PUPPETSERVER=puppet \
    WAITFORCERT=15s \
    PATH="/opt/puppetlabs/puppet/bin:$PATH" \
    container=docker \
    LANG=en_US.utf8 \
    TERM=linux

## Add puppet PC1 repo, install puppet agent and clear ssl folder (to be regenerated in container)
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs/puppetserver
##          /opt/puppetlabs/server/data/puppetserver/*
##          /var/log/puppetlabs/puppetserver/*
##          /etc/puppetlabs/puppet/ssl/*
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
        --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
        --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs \
    && yum -y install \
        https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm \
        epel-release \
    && yum -y update \
    && yum -y install \
        bash-completion \
        ca-certificates \
        git \
        less \
        which \
    && yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} \
    && yum clean all \
    ## the below section cleans up systemd to allow it to run in a container
    && (cd /lib/systemd/system/sysinit.target.wants/; for i in *; \
        do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; \
       done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;


COPY journal-console.service /usr/lib/systemd/system/journal-console.service
COPY quiet-console.conf /etc/systemd/system.conf.d/quiet-console.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh \
    && systemctl enable puppet.service \
    && systemctl enable journal-console.service


## This ONBUILD section creates a derived image that will configure r10k for the
## users environment.

## Set container hostname and puppetserver address. Puppet uses signed certificates
## to identify and authenticate itself with the server. Those certs use the hostname
## of the container when it first runs, so the honame of the container has to stay
## the same as build time.
# ONBUILD ARG HOSTNAME=puppetagent.example.com
# ONBUILD ARG HOSTS="puppet.example.com:192.168.10.50 puppet:192.168.10.50"
# ONBUILD ARG PUPPETSERVER=puppet
# ONBUILD ARG PUPPETENV=production
# ONBUILD ARG WAITFORCERT=15s
# ONBUILD RUN arrHosts=(${HOSTS}); \
#             for myhost in ${arrHosts[@]}; do \
#               myhost=(${myhost//:/ }); \
#               printf "%s\t%s\n" ${myhost[1]} ${myhost[0]} >> /etc/hosts; \
#             done

## Save the important stuff!
# VOLUME ["/etc/puppetlabs", \
#         "/opt/puppetlabs/puppet/cache", \
#         "/var/log/puppetlabs"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/init"]
