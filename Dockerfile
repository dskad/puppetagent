FROM centos:7
MAINTAINER Dan Skadra <dskadra@gmail.com>

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.2.*"
# ARG PUPPETAGENT_VERSION="1.2.6"

ENV PATH="/opt/puppetlabs/puppet/bin:$PATH" \
    container=docker \
    LANG=en_US.utf8 \
    TERM=linux

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

## Import repository keys
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
  --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs

## Add puppet PC1 repo, install puppet agent and support tool
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs
##          /opt/puppetlabs/puppet/cache
##          /opt/puppetlabs/server/data
##          /var/log/puppetlabs/puppetserver (if it exists)
##          /etc/puppetlabs/puppet/ssl
RUN yum -y install \
    https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm \
    epel-release \
  && yum -y update \
  && yum -y install \
    bash-completion \
    ca-certificates \
    less \
    logrotate \
    which \
  ## puppetserver depends on which, so we need to install it as a separate command
  && yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} \
  && yum clean all

## Clean up systemd folders to allow it to run in a container
## https://hub.docker.com/_/centos/
## Note: this needs to run after "yum update". If there is an upgrade to systemd/dbus
##      these files will get restored
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; \
        do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; \
       done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;

## Files to send journal logs to stdout for docker logs
COPY journal-console.service /usr/lib/systemd/system/journal-console.service
COPY quiet-console.conf /etc/systemd/system.conf.d/quiet-console.conf

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

## Enable services
RUN systemctl enable \
      puppet.service \
      journal-console.service

## This ONBUILD section will cause a derived image to contact the puppet server and
##  apply the configuration during the build process. Using puppet to finish building
##  the image

## Set container hostname and puppetserver address. Puppet uses signed certificates
##  to identify and authenticate itself with the server. Those certs use the hostname
##  of the container when it first runs, so the hostname of the running container has to stay
##  the same as build time.
# ONBUILD ARG HOSTNAME=puppetagent.example.com
ONBUILD ARG BUILDHOSTSFILE="puppet.example.com:192.168.10.50 puppet:192.168.10.50"
ONBUILD ARG BUILDSERVER=puppet
ONBUILD ARG BUILDENV=bootstrap
ONBUILD ARG BUILDWAITFORCERT=2m
ONBUILD ARG BUILDCERTNAME=test
ONBUILD ENV PUPPETSERVER=puppet \
            PUPPETENV=production \
            RUNINTERVAL=30m \
            WAITFORCERT=2m
ONBUILD RUN arrHosts=(${BUILDHOSTSFILE}); \
            for myhost in ${arrHosts[@]}; do \
              myhost=(${myhost//:/ }); \
              printf "%s\t%s\n" ${myhost[1]} ${myhost[0]} >> /etc/hosts; \
            done \
            ## Set puppet.conf settings
            # && sed -i "s/puppetservername/${PUPPETSERVER}/" /etc/puppetlabs/puppet/puppet.conf \
            # && sed -i "s/production/${PUPPETENV}/" /etc/puppetlabs/puppet/puppet.conf \
            # && sed -i "s/5m/${RUNINTERVAL}/" /etc/puppetlabs/puppet/puppet.conf \
            # && [ ! -v PXP_AGENT_OPTIONS ] || echo PXP_AGENT_OPTIONS=${PXP_AGENT_OPTIONS} >> /etc/sysconfig/pxp-agent \
            && puppet agent --verbose --no-daemonize --onetime \
                # --certname ${BUILDCERTNAME}-`date +%s | sha256sum | head -c 3; echo ` \
                --certname ${BUILDCERTNAME} \
                --waitforcert ${BUILDWAITFORCERT} \
                --environment ${BUILDENV} \
                --server ${BUILDSERVER} \
            && rm -rf /opt/puppetlabs/puppet/cache \
            && rm -rf /etc/puppetlabs/puppet/ssl

ONBUILD VOLUME /sys/fs/cgroup

## Additionally these volumes for the puppet agent should be added to the derived
##   image dockerfile to save the agent state and certs. Onbuld runs before the child
##   docker file, so any changes to the volums after the are declaired would be lost.
##   Therefore, they need to be declaired at the end of the child dockerfile.
##     "/etc/puppetlabs"
##     "/opt/puppetlabs/puppet/cache"
##     "/var/log/puppetlabs"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/init"]
