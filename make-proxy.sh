#!/bin/bash

##
# Variables
##

set -a													# export all variables

scriptdir=$(dirname "$(realpath "$0")") 								# set script directory



###
## Script
###
clear
echo
echo
echo "		###############################"
echo "		## Clickwork Proxy Installer ##"
echo "		###############################"
echo
echo
echo "	1) HAProxy"
echo "	2) HAProxy + nginx backend"
echo "	3) nginx (optionally + streams)"
echo
read -p $'   Please choose an option           \033[32m>\033[0m ' -r -n 1 # ask confirmation to continue script
echo -e "\n\n"

if [[ $REPLY =~ ^1 ]]; then

	bash "$scriptdir"/inst-haproxy.sh

elif [[ $REPLY =~ ^2 ]]; then

	bash "$scriptdir"/inst-haproxy.sh
	echo -e "\n\n"
	bash "$scriptdir"/inst-ngxproxy.sh

elif [[ $REPLY =~ ^3 ]]; then

	bash "$scriptdir"/inst-ngxproxy.sh

else
	echo

	while read -p $'	\033[1;91mBad\033[0m choice. Restart?  [Y/n]         \033[32m>\033[0m ' -r -n 1; do

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