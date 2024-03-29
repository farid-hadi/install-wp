# install-wp

A bash script to quickly install a WordPress site in your Linux-based development environment.

`install-wp` will download WordPress from WordPress.org, extract the files to your desired document root, create the database and database user with values extracted from _MySQL Option files_, create a wp-config.php file with the correct values and configure a server block or virtual host for the desired domain.

_install-wp is in no way affiliated with or endorsed by the WordPress Foundation or the WordPress open source project._

## Requirements

`install-wp` requires a Linux-based environment with Nginx or Apache web server, MySQL or MariaDB and PHP(FPM) installed.

Other requirements are CURL, Tar and AWK, which likely already are installed on your system.

## Configuration

**Before running the script for the first time** you'll need to create two [_MySQL Option files_](https://dev.mysql.com/doc/refman/8.0/en/option-files.html#option-file-syntax) in your home directory.

You can copy the files `install-wp/conf/mysql-opts-admin-template.cnf` and `install-wp/conf/mysql-opts-site-template.cnf` to create your option files.
These files must be placed in `~/install-wp/conf/` and must be named `mysql-opts-admin.cnf` and `mysql-opts-site.cnf` respectively.

**Important:** Make sure you restrict access to these files so that unauthorized users can't see your database passwords!

Copy the MySQL option files and set the correct permissions:

```
cp ~/install-wp/conf/mysql-opts-admin-template.cnf ~/install-wp/conf/mysql-opts-admin.cnf
chmod 600 ~/install-wp/conf/mysql-opts-admin.cnf
cp ~/install-wp/conf/mysql-opts-site-template.cnf ~/install-wp/conf/mysql-opts-site.cnf
chmod 600 ~/install-wp/conf/mysql-opts-site.cnf
```

Next, use your preferred text editor and update the usernames, passwords and database name in your newly created files.

`~/install-wp/conf/mysql-opts-admin.cnf` needs to contain a `[client]` section with a `user` and a `password`. This needs to be an existing database user with privileges required to create databases, users and set grants.

Example:

```
[client]
user=username
password=user_password
```

`~/install-wp/conf/mysql-opts-site.cnf` needs to contain a `[client]` section with a `user`, a `password` and a `database`. This database and user will be created for your by the script. These same values will also be entered into the created `wp-config.php` file.

Example:

```
[client]
user=username
password=user_password
database=database_name
```

## Usage

**Note:** The script must be run with `sudo`.

### Nginx

Example to install a new WordPress site with the domain _your.domain.com_, with a document root of _/var/www/your.domain.com/public_html_, served by an _Nginx_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -d your.domain.com --document-root /var/www/your.domain.com/public_html --nginx
```

After running the above, simply visit _your.domain.com_ to run the usual WordPress installation.

Example to install a new WordPress site _without creating a server block (virtual host)_, with a document root of _/var/www/wordpress/public_html_, served by an _Nginx_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh --document-root /var/www/wordpress/public_html --nginx
```

The above will not create a server block but will set the correct file permissions so that Nginx can access and serve the files.

### Apache

> [!TIP]
> The examples below use the flag `--apache2` but you can also use `--apache` or `--httpd`, no matter which distro you are using, and the script will automatically try to find which version of Apache is running on your system.

Example to install a new WordPress site with the domain _your.domain.com_, with a document root of _/var/www/your.domain.com/public_html_, served by an _Apache_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -d your.domain.com --document-root /var/www/your.domain.com/public_html --apache2
```

After running the above, simply visit _your.domain.com_ to run the usual WordPress installation.

Example to install a new WordPress site _without creating a virtual host_, with a document root of _/var/www/wordpress/public_html_, served by an _Apache_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh --document-root /var/www/wordpress/public_html --apache2
```

The above will not create a virtual host but will set the correct file permissions so that Apache can access and serve the files.
