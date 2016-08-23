FROM centos:7
MAINTAINER Dan Skadra <dskadra@gmail.com>

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.2.*"
# ARG PUPPETAGENT_VERSION="1.2.6"

ENV PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH" \
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
  ## puppet depends on which, so we need to install it with a separate yum command
  && yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} \
  && yum clean all

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

## This ONBUILD section will cause a derived image to contact the puppet server and
##  apply the configuration during the build process, using puppet to finish building
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
            && puppet agent --verbose --no-daemonize --onetime \
                --certname ${BUILDCERTNAME}-`date +%s | sha256sum | head -c 3; echo ` \
                # --certname ${BUILDCERTNAME} \
                --waitforcert ${BUILDWAITFORCERT} \
                --environment ${BUILDENV} \
                --server ${BUILDSERVER} \
            && rm -rf /opt/puppetlabs/puppet/cache \
            && rm -rf /etc/puppetlabs/puppet/ssl


## Additionally these volumes for the puppet agent should be added to the derived
##   image dockerfile to save the agent state and certs. Onbuld runs before the child
##   docker file, so any changes to the volumes after they are declared would be lost.
##   Therefore, they need to be declared at the end of the child dockerfile.
##     VOLUME /etc/puppetlabs
##     VOLUME /opt/puppetlabs/puppet/cache
##     VOLUME /var/log/puppetlabs

# ENTRYPOINT ["/docker-entrypoint.sh"]
# CMD ["/usr/bin/bash"]
