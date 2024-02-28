#!/bin/bash

# install-wp
# Bash script that downloads and installs WordPress at the specified location, with the specified domain and database.
# https://github.com/farid-hadi/install-wp

version="0.0.1-alpha"

# Print version function
function printVersion() {
	printf "install-wp version: $version\n"
}

# Print help text function
function printHelp() {
	printVersion
	printf "\n"
	printf "Quickly install a new WordPress site in your development environment.\n"
	printf "This script will download WordPress from WordPress.org, extract the files to your desired document root, create the database with values extracted from the install-wp-[admin|site]-opts files, create a wp-config.php file with the correct values and configure a server block / virtual host for the desired domain.\n"
	printf "\n"
	printf "Prior to running this script you need to create the below two 'MySQL Options files' with '[client] sections' in your home directory. "
	printf "You can copy the files install-wp/config/install-wp-admin-opts-template and install-wp/config/install-wp-site-opts-template to create your option files.\n"
	printf "\n"
	printf "IMPORTANT: Make sure you restrict access to your option files with e.g. chmod 600 so that others can't see your database passwords!\n"
	printf "\n"
	printf "MySQL Option Files:\n"
	printf "~/install-wp/config/install-wp-admin-opts\n"
	printf "  Needs to contain username and password for the database user that can create new databases and grants.\n"
	printf "~/install-wp/config/install-wp-site-opts\n"
	printf "  Needs to contain username, password and database name for the new database and user to create for this site.\n"
	printf "\n"
	printf "Usage: install-wp [options]\n"
	printf "\n"
	printf "If you don't pass any options the script will prompt you for the required data.\n"
	printf "\n"
	printf "Options:\n"
	printf "  -h, --help                    Display this help and exit.\n"
	printf "  -v, --version                 Display version and exit.\n"
	printf "  -d, --domain                  Set domain name of the site you're creating.\n"
	printf "  -doc-root, --document-root    Set document root of the site you're creating. I.e. where to install the WordPress core files.\n"
}

# Print help or version if prompted
while getopts ":vh" opt; do
	case $opt in
		v|version)
			printVersion
			exit 0;;
		h|help)
			printHelp
			exit 0;;
	esac
done

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

find_cmd=$(which find)
if [ "$find_cmd" == "" ]; then
	abort 1 "Aborted. find does not seem to be installed."
fi

nginx_cmd=$(which nginx)
if [ -z "$nginx_cmd" ]; then
	abort 1 "Aborted. nginx does not seem to be installed."
else
	# Get nginx user
	declare $(ps -eo "%u,%c,%a" | grep nginx | awk '
	BEGIN { FS="," }
	{gsub(/^[ \t]+|[ \t]+$/, "", $1)}
	{gsub(/^[ \t]+|[ \t]+$/, "", $3)}
	/worker process/ { print "nginx_user="$1; exit }
	')

	if [ -z "$nginx_user" ]; then
		abort 1 "Aborted. Could not get nginx user."
	fi
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

# Prompt for any missing required arguments
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
	$mkdir_cmd -p $document_root
fi
if [ ! $? -eq 0 ]; then
	abort 1 "Aborted. Could not create document root."
fi

# Get users home directory
user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
# Hidden tmp directory in install-wp/ in the user's home directory
user_home_tmp="$user_home/install-wp/.tmp"

if [ ! -d $user_home_tmp ]; then
	$mkdir_cmd $user_home_tmp
fi
if [ ! $? -eq 0 ]; then
	abort 1 "Aborted. Could not create temporary directory in home directory."
fi

# Check if we have a recent download of WordPress
printf "Checking for cached WordPress archive...\n"
if [ -f "$user_home_tmp/latest.tar.gz" ]; then
	$find_cmd "$user_home_tmp" -name "latest.tar.gz" -type f -user root -mmin +360 -delete
fi

# Download WordPress if we don't have a recent download
if [ ! -f "$user_home_tmp/latest.tar.gz" ]; then
	printf "Downloading WordPress...\n"
	$curl_cmd -L -o "$user_home_tmp/latest.tar.gz" https://wordpress.org/latest.tar.gz
	if [ ! $? -eq 0 ]; then
		if [ -f "$user_home_tmp/latest.tar.gz" ]; then
			rm "$user_home_tmp/latest.tar.gz"
		fi
		abort 1 "Aborted. Could not download WordPress."
	fi
fi

# Extract WordPress tar file
printf "Extracting files...\n"
$tar_cmd xzf "$user_home_tmp/latest.tar.gz" -C "$document_root" --strip-components=1

# Set file permission for document root
printf "Setting file permissions...\n"
chown -R $nginx_user:$nginx_user "$document_root"
chmod -R 770 "$document_root"

# Read MySQL option files and get required information
printf "Reading MySQL Option files...\n"
mysql_admin_opts_file="$user_home/install-wp/config/install-wp-admin-opts.cnf"
mysql_site_opts_file="$user_home/install-wp/config/install-wp-site-opts.cnf"

if [ ! -f $mysql_admin_opts_file ]; then
	abort 1 "Aborted. Could not find file install-wp/config/install-wp-admin-opts.cnf in home directory."
else
	# Check file permissions to ensure user doesn't have insecure options file
	file_permissions=$(stat -c %a $mysql_admin_opts_file)
	if [ ! $file_permissions -eq 600 ] && [ ! $file_permissions -eq 400 ]; then
		abort 1 "Aborted. Insecure file permissons on file install-wp/config/install-wp-admin-opts.cnf in home directory."
	fi
fi
if [ ! -f $mysql_site_opts_file ]; then
  abort 1 "Aborted. Could not find file install-wp/config/install-wp-site-opts.cnf in home directory."
else
	# Check file permissions to ensure user doesn't have insecure options file
	file_permissions=$(stat -c %a $mysql_site_opts_file)
	if [ ! $file_permissions -eq 600 ] && [ ! $file_permissions -eq 400 ]; then
		abort 1 "Aborted. Insecure file permissons on file install-wp/config/install-wp-site-opts.cnf in home directory."
	fi
fi

printf "${green}All done!${cf}\n"