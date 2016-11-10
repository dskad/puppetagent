FROM centos:7
MAINTAINER Dan Skadra <dskadra@gmail.com>

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

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.2.*"
# ARG PUPPETAGENT_VERSION="1.2.6"

## Add puppet PC1 repo, install puppet agent and support tool
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs
##          /opt/puppetlabs/puppet/cache
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
  ## Add default config for container based puppet agent
  ## && echo environment=puppet >> /etc/puppetlabs/puppet/puppet.conf \
  ## && echo tags=puppet >> /etc/puppetlabs/puppet/puppet.conf

CMD ["/usr/bin/bash"]
