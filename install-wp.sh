#!/bin/bash

# install-wp
# Bash script that downloads and installs WordPress at the specified location, with the specified domain and database.
# https://github.com/farid-hadi/install-wp

version="0.2.2-beta"

# Print version function
function printVersion() {
	printf "install-wp version: $version\n"
}

# Print help text function
function printHelp() {
	printVersion
	printf "\n"
	printf "Quickly install a new WordPress site in your development environment.\n"
	printf "This script will download WordPress from WordPress.org, extract the files to your desired document root, create the database and database user with values extracted from the MySQL Option files, create a wp-config.php file with the correct values and configure a server block / virtual host for the desired domain.\n"
	printf "\n"
	printf "Prior to running this script you need to create the below two 'MySQL Option files' with '[client] sections' in your home directory. "
	printf "You can copy the files install-wp/conf/mysql-opts-admin-template.cnf and install-wp/conf/mysql-opts-site-template.cnf to create your option files.\n"
	printf "\n"
	printf "IMPORTANT: Make sure you restrict access to your option files with e.g. chmod 600 so that unauthorized users can't see your database passwords!\n"
	printf "\n"
	printf "MySQL Option Files:\n"
	printf "~/install-wp/conf/mysql-opts-admin.cnf\n"
	printf "  Needs to contain username and password for an existing database user that can create new databases, users and grants.\n"
	printf "~/install-wp/conf/mysql-opts-site.cnf\n"
	printf "  Needs to contain username, password and database name for the new database and database user that you wish to be created for this site.\n"
	printf "\n"
	printf "Usage: install-wp [options]\n"
	printf "\n"
	printf "If you don't pass any options the script will prompt you for the required data.\n"
	printf "\n"
	printf "Options:\n"
	printf "  -h, --help                    Display this help and exit.\n"
	printf "  -v, --version                 Display version and exit.\n"
	printf "  -d, --domain                  Set domain name of the site you're creating.\n"
	printf "  -docroot, --document-root     Set document root of the site you're creating. I.e. where to install the WordPress core files.\n"
	printf "  --nginx                       Set your chosen web server to Nginx.\n"
	printf "\n"
	printf "Please also see documentation at https://github.com/farid-hadi/install-wp\n"
}

# Read arguments passed with command
while [ $# -gt 0 ]; do
	case "$1" in
		-v|--version)
			printVersion
			exit 0
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		-d|--domain)
			domain="$2"
			;;
		-docroot|--document-root)
			document_root="$2"
			;;
		--nginx)
			web_server="nginx"
			shift
			continue
			;;
		--apache|--apache2|--httpd)
			web_server="apache2"
			shift
			continue
			;;
		*)
			printf "${red}Error: Invalid arguments.${cf}\n"
			printf "Use --help for help with usage.\n"
			exit 1
	esac
	shift
	shift
done

# Text formatting
underline='\033[4m'
green='\033[0;32m'
red='\033[1;31m'
cf='\033[0m' # Clear formatting

# Function: Output message and exit with exit code
# Params: $1 = exit code, $2 = message
function abort() {
	if [ $1 -ne 0 ]; then
		printf "${red}$2${cf}\n"
	else
		printf "$2\n"
	fi
	exit $1
}

# Require root privileges
if [ $EUID -ne 0 ]; then
	abort 1 "Error: This script must be run as root."
fi

# Prompt for any missing arguments
if [ -z "$domain" ]; then
	read -p "Domain name (optional): " domain
fi

if [ -z "$document_root" ]; then
	read -e -p "Document root (where to place WordPress files): " document_root
fi

if [ -z "$web_server" ]; then
	read -p "Web server (nginx|apache2|httpd): " web_server
fi

# Set $web_server to "apache2" if user entered apache or httpd
if [ "$web_server" == "apache" ] || [ "$web_server" == "httpd" ]; then
	web_server="apache2"
fi

# Abort if any required arguments are missing
if [ -z "$document_root" ]; then
	abort 1 "Aborted. No document root supplied as argument."
fi
if [ -z "$web_server" ]; then
	abort 1 "Aborted. No web server supplied as argument."
fi
if [ "$web_server" != "nginx" ] && [ "$web_server" != "apache2" ]; then
	abort 1 "Aborted. Invalid value supplied for web server."
fi

# Check that the commands we need are installed and store their absolute paths in variables
mkdir_cmd=$(which mkdir)
if [ -z "$mkdir_cmd" ]; then
	abort 1 "Aborted. mkdir does not seem to be installed."
fi

curl_cmd=$(which curl)
if [ -z "$curl_cmd" ]; then
	abort 1 "Aborted. CURL does not seem to be installed."
fi

tar_cmd=$(which tar)
if [ -z "$tar_cmd" ]; then
	abort 1 "Aborted. tar does not seem to be installed."
fi

awk_cmd=$(which awk)
if [ -z "$awk_cmd" ]; then
	abort 1 "Aborted. AWK does not seem to be installed."
fi

find_cmd=$(which find)
if [ -z "$find_cmd" ]; then
	abort 1 "Aborted. find does not seem to be installed."
fi

mysql_cmd=$(which mysql)
if [ -z "$mysql_cmd" ]; then
	abort 1 "Aborted. MySQL/MariaDB does not seem to be installed."
fi

# Ask for verfication before beginning install
printf "Install WordPress site with below details?\n"
printf "Domain name: ${domain}\n"
printf "Document root: ${document_root}\n"
printf "Web server: ${web_server}\n"

printf "Continue? [yes/No]: "
read continue

if [ -z "$continue" ] || [ "$continue" != "yes" ]; then
	abort 1 "Aborted. No site created."
fi

unset continue

# If chosen web server is Nginx, get command and user
if [ "$web_server" == "nginx" ]; then
	nginx_cmd=$(which nginx)
	if [ -z "$nginx_cmd" ]; then
		abort 1 "Aborted. nginx does not seem to be installed."
	else
		# Get nginx user
		declare $(ps -eo "%u,%c,%a" | grep nginx | $awk_cmd '
		BEGIN { FS="," }
		{gsub(/^[ \t]+|[ \t]+$/, "", $1)}
		{gsub(/^[ \t]+|[ \t]+$/, "", $3)}
		$1 != "root" && $3~/worker process/ { print "web_server_user="$1; exit }
		')

		if [ -z "$web_server_user" ]; then
			abort 1 "Aborted. Could not get nginx user."
		fi
	fi
fi

# If chosen web server is Apache, get command and user
if [ "$web_server" == "apache2" ]; then
	apache2_or_httpd="apache2"
	apache_cmd=$(which apache2 2>/dev/null)
	if [ -z "$apache_cmd" ]; then
		apache2_or_httpd="httpd"
		apache_cmd=$(which httpd 2>/dev/null)
	fi
	if [ -z "$apache_cmd" ]; then
		abort 1 "Aborted. apache2 / httpd does not seem to be installed."
	else
		# Get apache user
		declare $(ps -eo "%u,%c,%a" | grep $apache2_or_httpd | $awk_cmd -v apache2_or_httpd="$apache2_or_httpd" '
		BEGIN { FS="," }
		{gsub(/^[ \t]+|[ \t]+$/, "", $1)}
		{gsub(/^[ \t]+|[ \t]+$/, "", $2)}
		$1 != "root" && $2 == apache2_or_httpd { print "web_server_user="$1; exit }
		')

		if [ -z "$web_server_user" ]; then
			abort 1 "Aborted. Could not get apache2 user."
		fi
	fi
fi

# Create the document root
printf "Creating document root...\n"
if [ -d $document_root ]; then
	abort 1 "Aborted. The doucment root already exists."
else
	$mkdir_cmd -p $document_root
fi
if [ $? -ne 0 ]; then
	abort 1 "Aborted. Could not create document root."
fi

# Get users home directory
user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
# Hidden tmp directory in install-wp/ in the user's home directory
user_home_tmp="$user_home/install-wp/.tmp"

if [ ! -d $user_home_tmp ]; then
	$mkdir_cmd $user_home_tmp
fi
if [ $? -ne 0 ]; then
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
	if [ $? -ne 0 ]; then
		if [ -f "$user_home_tmp/latest.tar.gz" ]; then
			rm "$user_home_tmp/latest.tar.gz"
		fi
		abort 1 "Aborted. Could not download WordPress."
	fi
fi

# Extract WordPress tar file and place WordPress core in document root
printf "Extracting files...\n"
$tar_cmd xzf "$user_home_tmp/latest.tar.gz" -C "$document_root" --strip-components=1

# Read MySQL option files and get required information
printf "Reading MySQL Option files...\n"
mysql_admin_opts_file="$user_home/install-wp/conf/mysql-opts-admin.cnf"
mysql_site_opts_file="$user_home/install-wp/conf/mysql-opts-site.cnf"

if [ ! -f $mysql_admin_opts_file ]; then
	abort 1 "Aborted. Could not find file install-wp/conf/mysql-opts-admin.cnf in home directory."
else
	# Check file permissions to ensure user doesn't have insecure options file
	file_permissions=$(stat -c %a $mysql_admin_opts_file)
	if [ $file_permissions -ne 600 ] && [ $file_permissions -ne 400 ]; then
		abort 1 "Aborted. Insecure file permissons on file install-wp/conf/mysql-opts-admin.cnf in home directory."
	fi
fi
if [ ! -f $mysql_site_opts_file ]; then
  abort 1 "Aborted. Could not find file install-wp/conf/mysql-opts-site.cnf in home directory."
else
	# Check file permissions to ensure user doesn't have insecure options file
	file_permissions=$(stat -c %a $mysql_site_opts_file)
	if [ $file_permissions -ne 600 ] && [ $file_permissions -ne 400 ]; then
		abort 1 "Aborted. Insecure file permissons on file install-wp/conf/mysql-opts-site.cnf in home directory."
	fi
fi

# Extract data from MySQL option file
declare $($awk_cmd '
BEGIN { FS="=|#" }
$1 == "user" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print "database_user="$2; next }
$1 == "password" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print "database_password="$2; next }
$1 == "database" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print "database_name="$2; next }
' "$mysql_site_opts_file" )

# Check that we have all the required database information
if [ -z "$database_user" ]; then
	abort 1 "Aborted. Could not extract database user from MySQL options file."
fi
if [ -z "$database_password" ]; then
	abort 1 "Aborted. Could not extract database password MySQL options file."
fi
if [ -z "$database_name" ]; then
	abort 1 "Aborted. Could not extract database name from MySQL options file."
fi

# Create database and database user
printf "Creating database...\n"
$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "USE $database_name;" &>/dev/null;
if [ $? -eq 0 ]; then
	abort 1 "Aborted. Database already exists."
fi

$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "CREATE DATABASE $database_name;" 1>/dev/null;
if [ $? -ne 0 ]; then
	abort 1 "Aborted. Could not create database."
fi

$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "CREATE USER IF NOT EXISTS '$database_user'@'localhost' IDENTIFIED BY '$database_password';" 1>/dev/null;
if [ $? -ne 0 ]; then
	# Since we couldn't create the user, let's delete the database we created
	$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "DROP DATABASE $database_name;" 1>/dev/null;
	abort 1 "Aborted. Could not create database user."
fi

$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "GRANT ALL ON $database_name.* TO '$database_user'@'localhost';" 1>/dev/null;
if [ $? -ne 0 ]; then
	# Since we couldn't set the grants, let's delete the database we created
	$mysql_cmd --defaults-extra-file="$mysql_admin_opts_file" -e "DROP DATABASE $database_name;" 1>/dev/null;
	abort 1 "Aborted. Could not set grants for database user."
fi

# Get salts from https://api.wordpress.org/secret-key/1.1/salt/ and save them in a tmp tile
printf "Downloading salts...\n"
wp_salts_tmp_file="wp-salts-"$(date +%s%N)".txt"
$curl_cmd -sS -o "$user_home_tmp/$wp_salts_tmp_file" https://api.wordpress.org/secret-key/1.1/salt/ && chmod 600 "$user_home_tmp/$wp_salts_tmp_file"
if [ $? -ne 0 ]; then
	if [ -f "$user_home_tmp/$wp_salts_tmp_file" ]; then
		rm "$user_home_tmp/$wp_salts_tmp_file"
	fi
	abort 1 "Aborted. Could not download salts."
fi

# Create wp-config.php with database information from MySQL option file for site
printf "Creating wp-config.php...\n"
$awk_cmd '
BEGIN{ OFS = "\047"; fname = ""; idx = 0 }
fname != FILENAME { fname = FILENAME; idx++ }
idx == 1 && $1 == "user" { gsub(/^[ \t]+|[ \t]+$/, "", $2); user = $2; next }
idx == 1 && $1 == "password" { gsub(/^[ \t]+|[ \t]+$/, "", $2); password = $2; next }
idx == 1 && $1 == "database" { gsub(/^[ \t]+|[ \t]+$/, "", $2); database = $2; next }
idx == 2 && /^define\(/ { salts[$2] = $4; next }
idx == 3 && /^define\(/ && $2~/DB_NAME/ { $4 = database }
idx == 3 && /^define\(/ && $2~/DB_USER/ { $4 = user }
idx == 3 && /^define\(/ && $2~/DB_PASSWORD/ { $4 = password }
idx == 3 && /^define\(/ && ($2 in salts) { $4 = salts[$2] }
idx == 3' FS="=|#" "$mysql_site_opts_file" FS="\047" "$user_home_tmp/$wp_salts_tmp_file" FS="\047" "$document_root/wp-config-sample.php" > "$document_root/wp-config.php"
if [ $? -ne 0 ]; then
	rm "$user_home_tmp/$wp_salts_tmp_file"
	abort 1 "Aborted. Could not create wp-config.php file."
fi

# Set file permission for document root
printf "Setting file permissions...\n"
chown -R $web_server_user:$web_server_user "$document_root"
chmod -R 770 "$document_root"

# Create Nginx server block for domain if web server is Nginx and domain is not none/localhost
if [ "$web_server" == "nginx" ] && [ -n "$domain" ] && [ "$domain" != "localhost" ] && [ "$domain" != "none" ]; then

	printf "Creating Nginx server block...\n"

	vhost_config_file="$domain"
	
	if [ -d "/etc/nginx/sites-available" ] && [ -d "/etc/nginx/sites-enabled" ]; then
		vhost_config_dir="/etc/nginx/sites-available"
	elif [ -d "/etc/nginx/vhosts.d" ]; then
		vhost_config_dir="/etc/nginx/vhosts.d"
		vhost_config_file="$domain.conf"
	elif [ -d "/etc/nginx/conf.d" ]; then
		vhost_config_dir="/etc/nginx/conf.d"
		vhost_config_file="$domain.conf"
	fi

	if [ -z "$vhost_config_dir" ]; then
		abort 1 "Aborted. Could not find location for server block configuration."
	fi

	php_fpm_sock=$($find_cmd /var/run/php/ -name "php*-fpm.sock" -type s -print -quit 2>/dev/null)
	if [ -z "$php_fpm_sock" ]; then
		php_fpm_sock=$($find_cmd "/var/run/php-fpm/" -name "*.sock" -type s -print -quit 2>/dev/null)
	fi

	if [ -z "$php_fpm_sock" ]; then
		abort 1 "Aborted. Could not find PHP FPM socket."
	fi

	read -r -d '' server_block_template <<"EOF"
# Created by install-wp
server {
	server_name DOMAIN;
	listen 80;
	listen [::]:80;
	root DOCROOT;
	index index.php index.html;

	location / {
		try_files $uri $uri/ /index.php$is_args$args;
	}

	location ~ \.php$ {
		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		try_files $fastcgi_script_name =404;
		set $path_info $fastcgi_path_info;
		include fastcgi_params;
		fastcgi_param PATH_INFO $path_info;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
		fastcgi_index index.php;
		fastcgi_pass unix:PHPFPMSOCK;
	}
}
EOF

	printf "$server_block_template" | $awk_cmd -v docroot="$document_root" -v domain="$domain" -v php_fpm_sock="$php_fpm_sock" '
	/^\tserver_name/ && $2 == "DOMAIN;" && /;$/ { $2 = domain";"; print "\t"$0; next }
	/^\troot/ && $2 == "DOCROOT;" && /;$/ { $2 = docroot";"; print "\t"$0; next }
	/^\t\tfastcgi_pass/ && $2 == "unix:PHPFPMSOCK;" && /;$/ { $2 = "unix:"php_fpm_sock";"; print "\t\t"$0; next } 1' > "$vhost_config_dir/$vhost_config_file"
	
	if [ $? -ne 0 ]; then
		abort 1 "Aborted. Could not create Nginx server block."
	else
		if [ "$vhost_config_dir" == "/etc/nginx/sites-available" ]; then
			ln -s "$vhost_config_dir/$vhost_config_file" /etc/nginx/sites-enabled
		fi
		printf "Reloading Nginx...\n"
		$nginx_cmd -s reload
	fi
	
fi

# Create Apache Virtual Host for domain if web server is Apache and domain is not none/localhost
if [ "$web_server" == "apache2" ] && [ -n "$domain" ] && [ "$domain" != "localhost" ] && [ "$domain" != "none" ]; then

	printf "Creating Apache virtual host...\n"

	vhost_config_file="$domain.conf"
	
	if [ -d "/etc/apache2/sites-available" ] && [ -d "/etc/apache2/sites-enabled" ]; then
		vhost_config_dir="/etc/apache2/sites-available"
	elif [ -d "/etc/httpd/sites-available" ] && [ -d "/etc/httpd/sites-enabled" ]; then
		vhost_config_dir="/etc/httpd/sites-available"
	elif [ -d "/etc/httpd/conf.d" ]; then
		vhost_config_dir="/etc/httpd/conf.d"
	fi

	if [ -z "$vhost_config_dir" ]; then
		abort 1 "Aborted. Could not find location for virtual host configuration."
	fi

	read -r -d '' virtual_host_template <<"EOF"
# Created by install-wp
<VirtualHost *:80>
	ServerName DOMAIN
	DocumentRoot DOCROOT

	DirectoryIndex index.php index.html

	<Directory DOCROOT>
		Options FollowSymLinks
		AllowOverride All
		Order allow,deny
		Allow from all
	</Directory>
</VirtualHost>
EOF

	printf "$virtual_host_template" | $awk_cmd -v docroot="$document_root" -v domain="$domain" '
	/^\tServerName/ && $2 == "DOMAIN" { $2 = domain; print "\t"$0; next }
	/^\tDocumentRoot/ && $2 == "DOCROOT" { $2 = docroot; print "\t"$0; next }
	/^\t<Directory/ && $2 == "DOCROOT>" { $2 = docroot">"; print "\t"$0; next } 1' > "$vhost_config_dir/$vhost_config_file"

	if [ $? -ne 0 ]; then
		abort 1 "Aborted. Could not create Apache virtual host."
	else
		if [ "$vhost_config_dir" == "/etc/apache2/sites-available" ]; then
			ln -s "$vhost_config_dir/$vhost_config_file" /etc/apache2/sites-enabled
		elif [ "$vhost_config_dir" == "/etc/httpd/sites-available" ]; then
			ln -s "$vhost_config_dir/$vhost_config_file" /etc/httpd/sites-enabled
		fi

		printf "Restarting Apache...\n"
		apachectl -k graceful &>/dev/null
		if [ $? -ne 0 ]; then
			systemctl restart httpd &>/dev/null
		fi

	fi

fi

# Clean up - delete tmp files
printf "Cleaning up...\n"
if [ -f "$user_home_tmp/$wp_salts_tmp_file" ]; then
	rm "$user_home_tmp/$wp_salts_tmp_file"
fi

printf "${green}All done!${cf}\n"