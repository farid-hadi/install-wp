#!/bin/bash

# wp-install
# Bash script that downloads and installs WordPress at the specified location, with the specified domain and database.

# Text formatting
underline='\033[4m'
green='\033[0;32m'
red='\033[1;31m'
cf='\033[0m' # Clear formatting

# Function: Output message and exit with exit code
# Params: $1 = exit code, $2 = message
function abort() {
	if [ ! $1 -eq 0 ]; then
		printf "${red}$2${cf}\n"
	else
		printf "$2\n"
	fi
	exit $1
}

# Require root privileges
if [[ $EUID -ne 0 ]]; then
	abort 1 "Error: This script must be run as root."
fi

# Check that the commands we need are installed and store their absolute paths in variables
mkdir_cmd=$(which mkdir)
if [ "$mkdir_cmd" == "" ]; then
	abort 1 "Aborted. mkdir does not seem to be installed."
fi

curl_cmd=$(which curl)
if [ "$curl_cmd" == "" ]; then
	abort 1 "Aborted. CURL does not seem to be installed."
fi

tar_cmd=$(which tar)
if [ "$tar_cmd" == "" ]; then
	abort 1 "Aborted. tar does not seem to be installed."
fi

# Read arguments passed with command
while [ $# -gt 0 ]; do
	case "$1" in
		-d|-domain|--domain)
			domain="$2"
			;;
		-doc-root|-document-root|--document-root)
			document_root="$2"
			;;
		*)
			printf "${red}Error: Invalid arguments.${cf}\n"
			printf "Valid arguments are: -d or -domain for domain name. -doc-root or -document-root for location to install WordPress files.\n"
			exit 1
	esac
	shift
	shift
done

# Prompt for missing arguments
if [ -z "$domain" ]; then
  read -p "Domain name: " domain
fi

if [ -z "$document_root" ]; then
  read -p "Document root (where to place WordPress files): " document_root
fi

# Ask for verfication before beginning install
printf "Install WordPress site with below details?\n"
printf "Domain name: ${domain}\n"
printf "Document root: ${document_root}\n"

printf "Continue? [yes/No]: "
read continue

if [ -z "$continue" ] || [ "$continue" != "yes" ]; then
  abort 1 "Aborted. No site created."
fi

unset continue

# Create the document root
printf "Creating document root...\n"
if [ -d $document_root ]; then
	abort 1 "Aborted. The doucment root already exists."
else
	$mkdir_cmd $document_root
fi
if [ ! $? -eq 0 ]; then
	abort 1 "Aborted. Could not create document root."
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
	abort 1 "Aborted. Could not create temporary directory in home directory."
fi
$curl_cmd -L -o "$user_home_tmp/latest.tar.gz" https://wordpress.org/latest.tar.gz
if [ ! $? -eq 0 ]; then
	abort 1 "Aborted. Could not download WordPress."
fi

# Empty .tmp directory in install-wp/ in the user's home directory
#printf "Deleting temporary files...\n"
#/usr/bin/rm -r $user_home_tmp

printf "${green}All done!${cf}\n"