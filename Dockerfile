FROM centos:7

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin"

## Latest by default, un-comment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.10.*"
# ARG PUPPETAGENT_VERSION="1.10.1"

## Current available releases: puppet5, puppet5-nightly, puppet6, puppet6-nightly
ENV PUPPET_RELEASE="puppet6"

RUN set -eo pipefail && if [[ -v DEBUG ]]; then set -x; fi && \
  # Import repository keys and add puppet repository
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \
  rpm -Uvh https://yum.puppetlabs.com/${PUPPET_RELEASE}/${PUPPET_RELEASE}-release-el-7.noarch.rpm && \
  \
  # Update and install stuff
  yum -y update && \
  yum -y install \
    puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} && \
  yum clean all && \
  rm -rf /var/cache/yum

CMD ["/usr/bin/bash"]
