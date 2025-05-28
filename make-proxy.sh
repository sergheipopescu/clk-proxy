#!/bin/bash

##
# Variables
##

set -a													# export all variables

scriptdir=$(dirname "$(realpath "$0")") 								# set script directory

cln=$(echo -en '\033[0m')
red=$(echo -en '\033[31m')
grn=$(echo -en '\033[32m')
ylw=$(echo -en '\033[33m')
cyn=$(echo -en '\033[36m')
bred=$(echo -en '\033[1;91m')

###
## Script
### 
clear
echo
echo "${cyn}"
echo "		#################################"
echo "		##  Clickwork Proxy Installer  ##"
echo "		#################################"
echo "${cln}"
echo
echo "	1) ${ylw}HAProxy${cln} + ${grn}nginx${cln} backend"
echo "	2) ${ylw}HAProxy${cln}"
echo "	3) ${grn}nginx${cln} (optionally + ${red}streams${cln})"
echo
read -p $"   Please choose an option           ${grn}>${cln} " -r -n 1 # ask confirmation to continue script
echo -e "\n\n"

if [[ $REPLY =~ ^1 ]]; then

	bash "$scriptdir"/inst-haproxy.sh
	echo -e "\n\n"
	bash "$scriptdir"/inst-ngxproxy.sh

elif [[ $REPLY =~ ^2 ]]; then

	bash "$scriptdir"/inst-haproxy.sh

elif [[ $REPLY =~ ^3 ]]; then

	bash "$scriptdir"/inst-ngxproxy.sh

else
	echo

	while read -p $"	${bred}Bad${cln} choice. Restart?  [Y/n]         ${grn}>${cln} " -r -n 1; do

		if [[ ${REPLY:-Y} =~ ^[Yy] ]]; then

			bash "$(realpath "$0")" && exit 0

		elif [[ ${REPLY:-Y} =~ ^[Nn] ]]; then

			echo -e "\n"
			exit

		else
			echo
		fi

	done

fi

echo Cleanup?
echo