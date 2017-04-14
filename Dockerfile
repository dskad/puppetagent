FROM centos:7

ENV PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH" \
    container=docker \
    LANG=en_US.utf8 \
    TERM=linux \
    FACTER_CONTAINER_ROLE="agent"

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.2.*"
# ARG PUPPETAGENT_VERSION="1.2.6"

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \

## Import repository keys
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
        --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
        --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \


## Add puppet PC1 repo, install puppet agent and support tool
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs
##          /opt/puppetlabs/puppet/cache
##          /etc/puppetlabs/puppet/ssl
  rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm

RUN yum -y update && \
    yum -y install \
      bash-completion \
      ca-certificates \
      less \
      logrotate \
      which && \

    ## puppet depends on which, so we need to install it with a separate yum command
    yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} && \
    yum clean all

CMD ["/usr/bin/bash"]
