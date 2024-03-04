# install-wp

A bash script to quickly install a WordPress site in your Linux-based development environment.

`install-wp` will download WordPress from WordPress.org, extract the files to your desired document root, create the database and database user with values extracted from _MySQL Option files_, create a wp-config.php file with the correct values and configure a server block / virtual host for the desired domain.

## Requirements

`install-wp` requires a Linux-based environment with Nginx, MySQL or MariaDB and PHP(FPM) installed.

## Configuration

**Before running the script the first time** you'll need to create two _MySQL Option files_ in your home directory.

You can copy the files `install-wp/config/install-wp-admin-opts-template.cnf` and `install-wp/config/install-wp-site-opts-template.cnf` to create your option files.
These files must be placed in `~/install-wp/config/` and must be named `install-wp-admin-opts.cnf` and `install-wp-site-opts.cnf` respectively.

**Important:** Make sure your restrict access to these files so that unauthorized users can't see your database passwords!

Copy the file MySQL option files and set the correct permissions

```
sudo cp ~/install-wp/config/install-wp-admin-opts-template.cnf ~/install-wp/config/install-wp-admin-opts.cnf
sudo chmod 600 ~/install-wp/config/install-wp-admin-opts.cnf
sudo cp ~/install-wp/config/install-wp-site-opts-template.cnf ~/install-wp/config/install-wp-site-opts.cnf
sudo chmod 600 ~/install-wp/config/install-wp-site-opts.cnf
```

`~/install-wp/config/install-wp-admin-opts.cnf` needs to contain a `[client]` section with a `user` and a `password`. This database user needs exist and needs to have the required privileges to be able to create databases, users and set grants.

Example:

```
[client]
user=username
password=user_password
```

`~/install-wp/config/install-wp-site-opts.cnf` needs to contain a `[client]` section with a `user`, a `password` and a `database`. This database user will be created for your by the script. These same values will also be entered into the created `wp-config.php` file.

Example:

```
[client]
user=username
password=user_password
database=database_name
```

## Usage

**Note:** The script must be run with `sudo`.

Example to install a new WordPress site with the domain your.domain.com, with a document root of /var/www/your.domain.com/public_html, served by an Nginx web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -d your.domain.com -docroot /var/www/your.domain.com/public_html --nginx
```

After running the above, simple visit your.domain.com to run the usual WordPress installation.

Example to install a new WordPress without creating a server block (virtual host), with a document root of /var/www/your.domain.com/public_html, served by an Nginx web server.

```
cd ~/install-wp/
sudo ./install-wp.sh -docroot /var/www/wordpress/public_html --nginx
```

The above will not create a server block but will set the correct file permissions so that Nginx can access and serve the files.
