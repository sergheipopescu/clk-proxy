#!/bin/bash

##
# Variables
##

set -a													# export all variables

scriptdir=$(dirname "$(realpath "$0")") 								# set script directory


###############################
## Install & configure nginx ##
###############################

# Add ondrej repo for newest version
add-apt-repository ppa:ondrej/nginx-mainline -y

# Install nginx
apt-get update
apt-get install nginx libnginx-mod-stream -y

# Security | Remove defaults
rm /etc/nginx/sites-enabled/default
rm /var/www/html/*
rmdir /var/www/html

# Security | Create pem certificate for blackhole
mkdir /etc/nginx/ssl
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/nginx/ssl/blackhole.key -out /etc/nginx/ssl/blackhole.pem -sha256 -days 3650 -nodes -subj "/CN=Cyg X-1"

# Security | Create vhost for blackhole
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

# SSL | Create dhparam file
openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparam.pem 4096

# SSL | Disable ssl protocols in default config
sed -i 's|ssl_protocols|# &|' /etc/nginx/nginx.conf
sed -i 's|ssl_prefer_server_ciphers|# &|' /etc/nginx/nginx.conf


# Install clk files

cp -f "$scriptdir"/confs/clk.ngx.conf /etc/nginx/conf.d/clk.ngx.conf
cp -f "$scriptdir"/confs/clk.streams.conf /etc/nginx/modules-available/clk.streams.conf
cp -f "$scriptdir"/snips/* /etc/nginx/snippets
cp -fr "$scriptdir"/blocks /etc/nginx

# Logging | Create streams log directory
mkdir /var/log/nginx/streams

# Install entld.proxy
cp -f "$scriptdir"/scripts/entld.proxy /usr/sbin/entld.proxy
chmod +x /usr/sbin/entld.proxy

# Install lampstart
cp -f "$scriptdir"/scripts/lampstart /usr/sbin/lampstart
chmod +x /usr/sbin/lampstart

# Logging | Enable loghost on default settings
sed -i '/access_log/c\	include /etc/nginx/snippets/clk.ngx.loghost.snip;\n	access_log /var/log/nginx/access.log loghost;' /etc/nginx/nginx.conf



#####################################################
## Install and configure Bad Bot Blocker for nginx ##
#####################################################

# download and run bbb installer
wget https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker
chmod +x /usr/local/sbin/install-ngxblocker
install-ngxblocker -x

# remove setup
rm /usr/local/sbin/setup-ngxblocker

# schedule ngxblocker
crontab -l | { cat; echo "0 5 * * 6 /usr/local/sbin/update-ngxblocker >/dev/null 2>&1"; } | crontab -


###
## Enable streams (or not)
##
echo
echo
read -p $'	nginx Streams are \033[1;91m[not]\033[0m enabled. Enable now?           \033[32m>\033[0m ' -r -n 3 # ask confirmation to continue script

if [[ $REPLY =~ ^[Yy]+ ]]; then

	# enable streams.conf
	ln -s /etc/nginx/modules-available/clk.streams.conf /etc/nginx/modules-enabled/clk.streams.conf

	# comment out default port in srvblocks
	sudo sed -i '/default SSL port/s/^/#/' /etc/nginx/blocks/ngx.srvblock
	sudo sed -i '/default SSL port/s/^/#/' /etc/nginx/blocks/ngx.srwblock
	sudo sed -i '/default SSL port/s/^/#/' /etc/nginx/sites-available/blackhole

	# comment in proxy port in srvblocks
	sudo sed -i '/proxy SSL port/s/^#//g' /etc/nginx/blocks/ngx.srvblock
	sudo sed -i '/proxy SSL port/s/^#//g' /etc/nginx/blocks/ngx.srwblock
	sudo sed -i '/proxy SSL port/s/^#//g' /etc/nginx/sites-available/blackhole

	# comment in Real IP
	sudo sed -i '/Set real IP/s/^#//g' /etc/nginx/blocks/ngx.srvblock
	sudo sed -i '/Real IP header/s/^#//g' /etc/nginx/blocks/ngx.srvblock
	sudo sed -i '/Set real IP/s/^#//g' /etc/nginx/blocks/ngx.srwblock
	sudo sed -i '/Real IP header/s/^#//g' /etc/nginx/blocks/ngx.srwblock
	sudo sed -i '/Set real IP/s/^#//g' /etc/nginx/sites-available/blackhole
	sudo sed -i '/Real IP header/s/^#//g' /etc/nginx/sites-available/blackhole
fi

echo -e "\033[1;34m\n\n Reloading nginx proxy ...\033[0m\n"

{ echo -e "\033[36m\ntesting nginx config...\033[0m\n"; sudo nginx -q -t; } || { echo -e "\n\033[1;91mnginx config test failed. Review errors and retry\n"; exit 1; }

systemctl restart nginx

rm -rf "$scriptdir"

echo -e "\n\033[1;32m   nginx proxy installed! \033[0m \n"