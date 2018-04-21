#!/bin/bash
# This script will install a dhcp server on a RHEL/Centos 7+ machine
# User inputs
DHCPINTERFACE="enps03"
SUBNET="10.0.2.0"
NETMASK="255.255.255.0"
STARTINGIP="10.0.2.20"
ENDINGIP="10.0.2.100"
ROUTER="10.0.2.2"
NAMESERVER="10.0.0.1"
BROADCAST="10.0.2.255"
DOMAIN="myserver.com"

# firewall needs to be running to add dhcp service 
FIREWALL=yes
#FIREWALL=no
# End of user inputs

PACKAGES="dhcp"

if [[ $EUID != "0" ]]
then
	echo "ERROR. You need to have root privileges to run this script"
	exit 1
fi

if systemctl -q is-active dhcpd 
then
	systemctl stop dhcpd
	systemctl -q disable dhcpd
fi

rm -rf /etc/sysconfig/dhcpd
rm -rf /etc/dhcp/dhcpd*.conf

echo "Installing packages........."
yum install -y -q $PACKAGES > /dev/null 2>&1
echo "Done"

# Listen for dhcp requests on this interface
echo "DHCPARGS=$DHCPINTERFACE" > /etc/sysconfig/dhcpd

# Create the dhcp config file
cat <<EOF > /etc/dhcp/dhcpd.conf
option domain-name "$DOMAIN";
option domain-name-servers 8.8.8.8, 8.8.4.4;

log-facility local6;

# This is our only DHCP server
authoritative;

default-lease-time 3600;
max-lease-time 86400;

# Define a LAN subnet
#
subnet $SUBNET netmask $NETMASK {
	range $STARTINGIP $ENDINGIP;
	option routers $ROUTER;
	option subnet-mask $NETMASK;
	option broadcast-address $BROADCAST;
	option domain-name-servers $NAMESERVER;
}

EOF

systemctl start dhcpd
systemctl -q enable dhcpd

if [[ $FIREWALL == "yes" ]] && systemctl -q is-active firewalld
then
	echo "Addind dhcp to firewall"
	firewall-cmd --permanent -q --add-service dhcp
	firewall-cmd --reload -q
fi
