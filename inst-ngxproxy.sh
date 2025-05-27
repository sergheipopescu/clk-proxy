#!/bin/bash

##
# Variables
##

set -a													# export all variables

scriptdir=$(dirname "$(realpath "$0")") 								# set script directory

okay () {
	echo -e "[\033[32m OK \033[0m]\n"								# print okay function
}

fail () {
	echo -e "\n \033[1;91m[FAILED]\033[0m"; echo; exit 1						# print fail and exit function
}

spinny () {
	while :; do for c in / - \\ \|; do printf '%s\b' "$c"; sleep 0.1; done; done			# spinner
}

makespin () {
        eval "spinny & $1 &> /dev/null || fail ; { okay; kill $! && wait $!; } 2>/dev/null"
}

nginx-backend () {

			# comment out default port in srvblocks
		sed -i '/default SSL port/s/^/#/' /etc/nginx/blocks/ngx.srvblock
		sed -i '/default SSL port/s/^/#/' /etc/nginx/blocks/ngx.srwblock
		sed -i '/default SSL port/s/^/#/' /etc/nginx/sites-available/blackhole

		# comment in proxy port in srvblocks
		sed -i '/proxy SSL port/s/^#//g' /etc/nginx/blocks/ngx.srvblock
		sed -i '/proxy SSL port/s/^#//g' /etc/nginx/blocks/ngx.srwblock
		sed -i '/proxy SSL port/s/^#//g' /etc/nginx/sites-available/blackhole

		# comment in Real IP
		sed -i '/Set real IP/s/^#//g' /etc/nginx/blocks/ngx.srvblock
		sed -i '/Real IP header/s/^#//g' /etc/nginx/blocks/ngx.srvblock
		sed -i '/Set real IP/s/^#//g' /etc/nginx/blocks/ngx.srwblock
		sed -i '/Real IP header/s/^#//g' /etc/nginx/blocks/ngx.srwblock
		sed -i '/Set real IP/s/^#//g' /etc/nginx/sites-available/blackhole
		sed -i '/Real IP header/s/^#//g' /etc/nginx/sites-available/blackhole
}

###
## Script
###

echo "		###############################"
echo "		## Install & configure nginx ##"
echo "		###############################"
echo
echo


# Add ondrej repo for newest version
echo -n "Add nginx repository ............................ "
makespin "add-apt-repository ppa:ondrej/nginx -y"

# Update repositories
echo -n "Updating repositories ........................... "
makespin "apt-get update"

# Install nginx
echo -n "Installing nginx ................................ "
makespin "apt-get install nginx -y"

# Security | Remove defaults
echo -n "Removing defaults ............................... "
rm /etc/nginx/sites-enabled/default
rm /var/www/html/*
rmdir /var/www/html
okay

# Security | Create pem certificate for blackhole
echo -n "Creating default certificate for blackhole ...... "
mkdir /etc/nginx/ssl
makespin "openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/nginx/ssl/blackhole.key -out /etc/nginx/ssl/blackhole.pem -sha256 -days 3650 -nodes -subj "/CN=Cyg X-1""

# Security | Create vhost for blackhole
echo -n "Creating blackhole .............................. "
echo -e '
# Blackhole server for requests without SNI
server {
	
	listen		80 default_server;
	listen		443 default_server ssl;						# default SSL port
#	listen 9443 ssl proxy_protocol;							# proxy SSL port
	ssl_certificate     /etc/nginx/ssl/blackhole.pem;				# SSL certificate
	ssl_certificate_key /etc/nginx/ssl/blackhole.key;				# SSL Key
	access_log /var/log/nginx/blackhole.log loghost;				# logging with loghost

	return 444;
}
'|tee /etc/nginx/sites-available/blackhole > /dev/null

# Security | Enable blackhole srvblock
ln -s /etc/nginx/sites-available/blackhole /etc/nginx/sites-enabled/blackhole
okay

# SSL | Create dhparam file
echo -n "Creating dhparam file ........................... "
makespin "openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparam.pem 4096"

# SSL | Disable ssl protocols in default config
echo -n "Cleanup default config .......................... "
sed -i 's|ssl_protocols|# &|' /etc/nginx/nginx.conf
sed -i 's|ssl_prefer_server_ciphers|# &|' /etc/nginx/nginx.conf
okay

# Install clk files
echo -n "Installing custom configuration and scripts ..... "
cp -f "$scriptdir"/confs/clk.ngx.conf /etc/nginx/conf.d/clk.ngx.conf
cp -f "$scriptdir"/snips/* /etc/nginx/snippets
cp -fr "$scriptdir"/blocks /etc/nginx

# Install entld.proxy
cp -f "$scriptdir"/scripts/entld.proxy /usr/sbin/entld.proxy
chmod +x /usr/sbin/entld.proxy

# Install lampstart
cp -f "$scriptdir"/scripts/lampstart /usr/sbin/lampstart
chmod +x /usr/sbin/lampstart

# Logging | Enable loghost on default settings
sed -i '/access_log/c\	include /etc/nginx/snippets/clk.ngx.loghost.snip;\n	access_log /var/log/nginx/access.log loghost;' /etc/nginx/nginx.conf
okay



###
## Install and configure Bad Bot Blocker for nginx
###

echo -n "Installing Bad Bot Blocker for nginx ............"
# download and run bbb installer
wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker >/dev/null
chmod +x /usr/local/sbin/install-ngxblocker >/dev/null
install-ngxblocker -x >/dev/null

# remove setup
rm /usr/local/sbin/setup-ngxblocker >/dev/null

# schedule ngxblocker
crontab -l | { cat; echo "0 5 * * 6 /usr/local/sbin/update-ngxblocker >/dev/null 2>&1"; } | crontab -
okay


###
## Enable streams (or not)
##

 
if command -v haproxy &>/dev/null; then					# Check if haproxy is installed

	nginx-backend
	echo

else
	echo
	read -p $'	nginx Streams are \033[1;91m[not]\033[0m enabled. Enable now?           \033[32m>\033[0m ' -r -n 3 # ask confirmation to continue script

	if [[ $REPLY =~ ^[Yy]+ ]]; then

		# Install mod-stream
		echo -n "Installing nginx stream module .................. "
		makespin "apt-get install libnginx-mod-stream -y"

		echo -n "Configuring nginx streams ....................... "

		# Copy config and enable streams.conf
		cp -f "$scriptdir"/confs/clk.streams.conf /etc/nginx/modules-available/clk.streams.conf
		ln -s /etc/nginx/modules-available/clk.streams.conf /etc/nginx/modules-enabled/clk.streams.conf

		nginx-backend

		# Logging | Create streams log directory
		mkdir /var/log/nginx/streams
		okay
	fi

fi

echo -e "\033[1;34m\n\n Reloading nginx proxy ...\033[0m\n"

{ echo -e "\033[36m\ntesting nginx config...\033[0m\n"; sudo nginx -q -t; } || { echo -e "\n\033[1;91mnginx config test failed. Review errors and retry\n"; exit 1; }

systemctl restart nginx

rm -rf "$scriptdir"

echo -e "\n\033[1;32m   nginx proxy installed! \033[0m \n"