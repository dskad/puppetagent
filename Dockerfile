FROM centos:7

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin" \
    container=docker \
    LANG=en_US.utf8 \
    TERM=linux \
    FACTER_CONTAINER_ROLE="agent"

## Latest by default, un-comment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.10.*"
# ARG PUPPETAGENT_VERSION="1.10.1"

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
\
## Import repository keys
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
      --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
      --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \
\
## Add the proper puppet platform repo, install puppet agent and support tool
## The following are owned by the puppet user/group, the rest of the install is owned by root
##    /run/puppetlabs
##    /opt/puppetlabs/puppet/cache
##    /etc/puppetlabs/puppet/ssl
  rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm && \
  yum -y update && \
  yum -y install \
    bash-completion \
    ca-certificates \
    less \
    logrotate \
    which && \
\
    ## puppet depends on which, so we need to install it with a separate yum command
  yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} && \
\
  # Make environment use hiera v5 layout
  #rm -f /etc/puppetlabs/puppet/hiera.yaml && \
\
  yum clean all

CMD ["/usr/bin/bash"]
