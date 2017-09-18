#!/bin/bash -v

set -ex

if [ "x$PRECONFIG" == "xiprejecter" ]; then
PNDA_MIRROR_IP=$(echo $PNDA_MIRROR | awk -F'[/:]' '/http:\/\//{print $4}')

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[ipreject] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## Log and reject all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[ipreject] " --log-level 7 -m state --state NEW
iptables -A LOGGING -d  $PNDA_MIRROR_IP/32 -j ACCEPT # PNDA mirror
if [ "x$RD_IP" != "x" ]; then
iptables -A LOGGING -d  $RD_IP/32 -j ACCEPT # PNDA client
fi
if [ "x$NTP_SERVERS" != "x" ]; then
iptables -A LOGGING -d  $NTP_SERVERS -j ACCEPT # NTP server
fi
iptables -A LOGGING -d  10.0.0.0/16 -j ACCEPT      # PNDA network
iptables -A LOGGING -j REJECT
fi


DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)
if [ "x$DISTRO" == "xubuntu" ]; then
  export DEBIAN_FRONTEND=noninteractive
  # give the local mirror the first priority 
  sed -i "1ideb $PNDA_MIRROR/mirror_deb/ ./" /etc/apt/sources.list
  wget -O - $PNDA_MIRROR/mirror_deb/pnda.gpg.key | apt-key add -
  (curl -L 'https://archive.cloudera.com/cm5/ubuntu/trusty/amd64/cm/archive.key' | apt-key add - ) && echo 'deb [arch=amd64] https://archive.cloudera.com/cm5/ubuntu/trusty/amd64/cm/ trusty-cm5.9.0 contrib' > /etc/apt/sources.list.d/cloudera-manager.list
  (curl -L 'http://repo.saltstack.com/apt/ubuntu/14.04/amd64/archive/2015.8.11/SALTSTACK-GPG-KEY.pub' | apt-key add - ) && echo 'deb [arch=amd64] http://repo.saltstack.com/apt/ubuntu/14.04/amd64/archive/2015.8.11/ trusty main' > /etc/apt/sources.list.d/saltstack.list
  (curl -L 'https://deb.nodesource.com/gpgkey/nodesource.gpg.key' | apt-key add - ) && echo 'deb [arch=amd64] https://deb.nodesource.com/node_6.x trusty main' > /etc/apt/sources.list.d/nodesource.list
  apt-get update

elif [ "x$DISTRO" == "xrhel" ]; then

if [ "x$YUM_OFFLINE" == "x" ]; then
RPM_EXTRAS=rhui-REGION-rhel-server-extras
RPM_OPTIONAL=rhui-REGION-rhel-server-optional
yum-config-manager --enable $RPM_EXTRAS $RPM_OPTIONAL
yum install -y yum-plugin-priorities yum-utils 
PNDA_REPO=${PNDA_MIRROR/http\:\/\//}
PNDA_REPO=${PNDA_REPO/\//_mirror_rpm}
yum-config-manager --add-repo $PNDA_MIRROR/mirror_rpm
yum-config-manager --setopt="$PNDA_REPO.priority=1" --enable $PNDA_REPO
else
mkdir -p /etc/yum.repos.d.backup/
mv /etc/yum.repos.d/* /etc/yum.repos.d.backup/
yum-config-manager --add-repo $PNDA_MIRROR/mirror_rpm
fi


rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-redhat-release
rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-mysql
rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-cloudera
rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-EPEL-7
rpm --import $PNDA_MIRROR/mirror_rpm/SALTSTACK-GPG-KEY.pub
rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-CentOS-7
rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-Jenkins

fi
