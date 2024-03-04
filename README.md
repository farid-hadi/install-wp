# install-wp

A bash script to quickly install a WordPress site in your Linux-based development environment.

`install-wp` will download WordPress from WordPress.org, extract the files to your desired document root, create the database and database user with values extracted from _MySQL Option files_, create a wp-config.php file with the correct values and configure a server block / virtual host for the desired domain.

## Requirements

`install-wp` requires a Linux-based environment with Nginx, MySQL or MariaDB and PHP(FPM) installed.

## Configuration

**Before running the script for the first time** you'll need to create two [_MySQL Option files_](https://dev.mysql.com/doc/refman/8.0/en/option-files.html#option-file-syntax) in your home directory.

You can copy the files `install-wp/config/install-wp-admin-opts-template.cnf` and `install-wp/config/install-wp-site-opts-template.cnf` to create your option files.
These files must be placed in `~/install-wp/config/` and must be named `install-wp-admin-opts.cnf` and `install-wp-site-opts.cnf` respectively.

**Important:** Make sure your restrict access to these files so that unauthorized users can't see your database passwords!

Copy the MySQL option files and set the correct permissions:

```
cp ~/install-wp/config/install-wp-admin-opts-template.cnf ~/install-wp/config/install-wp-admin-opts.cnf
chmod 600 ~/install-wp/config/install-wp-admin-opts.cnf
cp ~/install-wp/config/install-wp-site-opts-template.cnf ~/install-wp/config/install-wp-site-opts.cnf
chmod 600 ~/install-wp/config/install-wp-site-opts.cnf
```

Next, use your preferred text editor and update the usernames, passwords and database name in your newly created files.

`~/install-wp/config/install-wp-admin-opts.cnf` needs to contain a `[client]` section with a `user` and a `password`. This database user needs exist and needs to have the required privileges to be able to create databases, users and set grants.

Example:

```
[client]
user=username
password=user_password
```

`~/install-wp/config/install-wp-site-opts.cnf` needs to contain a `[client]` section with a `user`, a `password` and a `database`. This database and user will be created for your by the script. These same values will also be entered into the created `wp-config.php` file.

Example:

```
[client]
user=username
password=user_password
database=database_name
```

## Usage

**Note:** The script must be run with `sudo`.

Example to install a new WordPress site with the domain _your.domain.com_, with a document root of _/var/www/your.domain.com/public_html_, served by an _Nginx_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -d your.domain.com -docroot /var/www/your.domain.com/public_html --nginx
```

After running the above, simply visit _your.domain.com_ to run the usual WordPress installation.

Example to install a new WordPress _without creating a server block (virtual host)_, with a document root of _/var/www/your.domain.com/public_html_, served by an _Nginx_ web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -docroot /var/www/wordpress/public_html --nginx
```

The above will not create a server block but will set the correct file permissions so that Nginx can access and serve the files.
