#!/usr/bin/env bash
#
# Software License Agreement (BSD License)
#
# Copyright (c) 2009-2012, Eucalyptus Systems, Inc.
# All rights reserved.
#
# Redistribution and use of this software in source and binary forms, with or
# without modification, are permitted provided that the following conditions
# are met:
#
#   Redistributions of source code must retain the above
#   copyright notice, this list of conditions and the
#   following disclaimer.
#
#   Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the
#   following disclaimer in the documentation and/or other
#   materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# author: Andrew Hamilton
#

######
# Install chef on CentOS 5 
#
# After the installation, chef-solo will install apache2 from the OpsCode
# cookbook repo on GitHub.
######

YUM=`which yum`
RPM=`which rpm`
CURL=`which curl`
HOSTNAME=`which hostname`
RUBY=""
GEM=""

SYSTEM_NAME="chef.mydomain.int"
SHORT_NAME=`echo ${SYSTEM_NAME} | cut -d'.' -f1`

TMP_DIR="/tmp/"
DEFAULT_DIR="/root/"

CHEF=""
CHEF_DIR="/var/chef-solo/"

#######
# Set the hostname of the system.
#######
hostname ${SYSTEM_NAME}
if [ -z `cat /etc/sysconfig/network | grep HOSTNAME` ]; then
    echo "HOSTNAME=${SYSTEM_NAME}" >> /etc/sysconfig/network
else
    sed -i -e "s/\(HOSTNAME=\).*/\1${SYSTEM_NAME}/" /etc/sysconfig/network
fi

sed -i -e "s/\(localhost.localdomain\)/${SYSTEM_NAME} ${SHORT_NAME} \1/" /etc/hosts

${YUM} -y update

#######
# Setup the required repos. EPEL, Aegisco, and rbel.
#######
${CURL} -o /etc/yum.repos.d/aegisco.repo http://rpm.aegisco.com/aegisco/el5/aegisco.repo

${RPM} -Uhv http://rbel.frameos.org/rbel5

${CURL} -o ${DEFAULT_DIR}/epel-release-5-4.noarch.rpm http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm
${RPM} -Uhv ${DEFAULT_DIR}/epel-release-5-4.noarch.rpm 

########
# Install ruby and required tools for building the system
########
${YUM} install -y ruby-1.8.7.352 ruby-libs-1.8.7.352 ruby-devel.x86_64 ruby-ri ruby-rdoc ruby-shadow gcc gcc-c++ automake autoconf make curl dmidecode

RUBY=`which ruby`
########
# Setup RubyGems
########
${CURL} -o ${TMP_DIR}/rubygems-1.8.10.tgz http://production.cf.rubygems.org/rubygems/rubygems-1.8.10.tgz 
tar xzvf ${TMP_DIR}/rubygems-1.8.10.tgz -C ${TMP_DIR}
${RUBY} ${TMP_DIR}/rubygems-1.8.10/setup.rb --no-format-executable

GEM=`which gem`
########
# Setup the chef ruby gem
########
${GEM} install chef --no-ri --no-rdoc

########
# **** NOTE ****
#
# The chef client is now installed. You can remove the rest of this script if you
# do not wish to install apache2. This is a proof of concept part of the script
# and is not needed.
########

########
# Now use chef-solo to install apache2
########

CHEF=`which chef-solo`
########
# Setup the basic configuration files needed
########
cat >>${DEFAULT_DIR}/solo.rb <<EOF
file_cache_path "${CHEF_DIR}"
cookbook_path [ "${CHEF_DIR}/cookbooks" ]
EOF

cat >>${DEFAULT_DIR}/node.json <<EOF
{
    "run_list": [ "recipe[apache2]" ]
}
EOF

########
# Setup up cookbooks directory for chef solo
########
mkdir -p ${CHEF_DIR}/cookbooks

########
# Download and untar the cookbooks provided by OpsCode on GitHub
########
${CURL} -o ${DEFAULT_DIR}/cookbooks.tgz https://nodeload.github.com/opscode/cookbooks/tarball/master
tar xzvf ${DEFAULT_DIR}/cookbooks.tgz -C ${DEFAULT_DIR}

########
# Add the apache2 cookbook to the chef solo cookbooks directory
########
cp -R ${DEFAULT_DIR}/opscode-cookbooks-*/apache2 ${CHEF_DIR}/cookbooks

########
# Run the node.rb JSON file to install apache2
########
${CHEF} -c ${DEFAULT_DIR}/solo.rb -j ${DEFAULT_DIR}/node.json 
