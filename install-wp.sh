#!/bin/bash

# wp-install
# Bash script that downloads and installs WordPress at the specified location, with the specified domain and database.

# Text formatting
underline='\e[4m'
green='\e[0;32m'
red='\e[0;31m'
cf='\e[0m' # Clear formatting

# Require root privileges
if [[ $EUID -ne 0 ]]; then
	printf "${red}Error:${cf} This script must be run as root.\n"
	exit 1;
fi

# Function: Output message and exit with exit code
# Params: $1 = exit code, $2 = message
function abort() {
	printf $2
	exit $1;
}

# Store the absolute paths to the commands we're going to use in variables
mkdir_cmd=$(which mkdir)
if [ "$mkdir_cmd" == "" ]; then
  abort 1 "${red}Aborted.${cf} mkdir does not seem to be installed."
fi

curl_cmd=$(which curl)
if [ "$curl_cmd" == "" ]; then
  abort 1 "Aborted. CURL does not seem to be installed."
fi

# Get users home directory
user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
# Hidden tmp directory in install-wp/ in the user's home directory
user_home_tmp="$user_home/install-wp/.tmp/"

# Download WordPress
printf "Downloading WordPress...\n"
if [ ! -d $user_home_tmp ]; then
	$mkdir_cmd $user_home_tmp
fi
if [ ! $? -eq 0 ]; then
	abort 1 "${red}Aborted.${cf} Could not create temporary directory in home directory."
fi
$curl_cmd -L -o "$user_home_tmp/latest.tar.gz" https://wordpress.org/latest.tar.gz
if [ ! $? -eq 0 ]; then
	/usr/bin/rm -r $user_home_tmp
	abort 1 "${red}Aborted.${cf} Could not download WordPress."
fi

# Empty .tmp directory in install-wp/ in the user's home directory
#printf "Deleting temporary files...\n"
#/usr/bin/rm -r $user_home_tmp

printf "${green}All done!${cf}\n"