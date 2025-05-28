#!/bin/bash

##
# Variables
##

set -a													# export all variables

scriptdir=$(dirname "$(realpath "$0")") 								# set script directory

cln=$(echo -en '\033[0m')
grn=$(echo -en '\033[32m')
cyn=$(echo -en '\033[36m')
bred=$(echo -en '\033[1;91m')


okay () {
	echo -e "[${grn} OK ${cln}]\n"								# print okay function
}

fail () {
	echo -e "\n ${bred}[FAILED]${cln}\n"; exit 1						# print fail and exit function
}

spinny () {
	while :; do for c in "   /" "   -" "   \\" "   \|"; do printf '%s\b' "$c"; sleep 0.1; done; done			# spinner
}

makespin () {
        eval "spinny & $1 &> /dev/null || fail ; { okay; kill $! && wait $!; } 2>/dev/null"
}



###
## Script
###

echo "${cyn}"
echo "		#################################"
echo "		## Install & configure HAProxy ##"
echo "		#################################"
echo "${cln}"
echo

# cursor off
tput civis

# Update repositories
echo -n "Updating repositories ........................... "
makespin "apt-get update"

# Install HAProxy
echo -n "Installing HAProxy .............................. "
makespin "apt-get install haproxy -y"

echo -n "Installing HAProxy customization ................ "

# Backup default config
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

# Copy custom config
cp "$scriptdir"/confs/haproxy.cfg /etc/haproxy/haproxy.cfg

# Create log directory
mkdir /var/log/HAProxy

# Modify HAProxy rsyslog.d log file location and template
sed -i '1i\# LogFormat\ntemplate(name="HAProxy" type="list") {\n    property(name="msg" spifno1stsp="on" )\n    property(name="msg" droplastlf="on" )\n    constant(value="\\n")\n    }\n' /etc/rsyslog.d/49-haproxy.conf
sed -i 's|/var/log/haproxy.log|/var/log/haproxy/haproxy.log;HAProxy|' /etc/rsyslog.d/49-haproxy.conf

# Touch mapfiles
echo -e "#SNI\n" | tee /etc/haproxy/localdomains.file >/dev/null
echo -e "#SNI	Remote Server\n" | tee /etc/haproxy/remotedomains.map >/dev/null

# Install entld.hpx
cp -f "$scriptdir"/scripts/entld.hpx /usr/sbin/entld.hpx
chmod +x /usr/sbin/entld.hpx

# Modify HAProxy logrotate.d logs location
sed -i 's|/var/log/haproxy.log|/var/log/haproxy/*.log|' /etc/logrotate.d/haproxy

# Ignore HAProxy run time process in lfd
echo -e "\nexe:/usr/sbin/haproxy" | tee -a /etc/csf/csf.pignore >/dev/null
systemctl restart csf lfd

okay

# Cursor on
tput cnorm