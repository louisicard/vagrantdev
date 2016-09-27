#! /usr/bin/env bash

# Variables
APPENV=local
DBPASSWD=password

echo -e "\n--- Installing now... ---\n"

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Install base packages ---\n"
apt-get -y install vim curl build-essential python-software-properties git > /dev/null 2>&1

echo -e "\n--- Add some repos to update our distro ---\n"
add-apt-repository ppa:ondrej/php5 > /dev/null 2>&1
add-apt-repository ppa:chris-lea/node.js > /dev/null 2>&1

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Install MySQL specific packages and settings ---\n"
echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get -y install mysql-server-5.5 phpmyadmin > /dev/null 2>&1

echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get -y install php5 apache2 libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-mysql php-apc php5-xdebug > /dev/null 2>&1

echo -e "\n--- Enabling mod-rewrite ---\n"
a2enmod rewrite > /dev/null 2>&1

echo -e "\n--- Allowing Apache override to all ---\n"
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

echo -e "\n--- We definitly need to see the PHP errors, turning them on ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini


a2dissite default > /dev/null 2>&1
a2dissite default-ssl > /dev/null 2>&1
service apache2 restart > /dev/null 2>&1

rm -f /etc/apache2/sites-available/*
rm -f /etc/apache2/sites-enabled/*

echo -e "\n--- Configure Apache to use phpmyadmin ---\n"
cat > /etc/apache2/ports.conf <<EOF
NameVirtualHost *:80
Listen 80
NameVirtualHost *:81
Listen 81
NameVirtualHost *:82
Listen 82

<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

cat > /etc/apache2/sites-available/phpmyadmin <<EOF
<VirtualHost *:81>
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/phpmyadmin
    DirectoryIndex index.php
    ErrorLog ${APACHE_LOG_DIR}/phpmyadmin-error.log
    CustomLog ${APACHE_LOG_DIR}/phpmyadmin-access.log combined
</VirtualHost>
EOF
a2ensite phpmyadmin > /dev/null 2>&1

echo -e "\n--- Add environment variables to Apache ---\n"
cat > /etc/apache2/sites-available/default <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/default
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
mkdir /var/www/default
cat > /var/www/default/index.html <<EOF
<html>
<head><title>Default</title></head>
<body>
This is the default site
</body>
</html>
EOF
a2ensite default > /dev/null 2>&1


echo -e "\n--- Creating Drupal site ---\n"
if [ ! -d "/var/www/drupal" ]; then
  mysql -uroot -p$DBPASSWD -e "CREATE DATABASE drupal CHARSET utf8"
  cd /var/www
  wget https://ftp.drupal.org/files/projects/drupal-8.1.10.tar.gz > /dev/null 2>&1
  tar xzf drupal-8.1.10.tar.gz > /dev/null 2>&1
  mv drupal-8.1.10 drupal
  mkdir drupal/sites/default/files
  chmod -R 777 drupal/sites/default/files
  cat > /etc/apache2/sites-available/drupal <<EOF
<VirtualHost *:82>
    DocumentRoot /var/www/drupal
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
fi
a2ensite drupal > /dev/null 2>&1

echo -e "\n--- Restarting Apache ---\n"
service apache2 restart > /dev/null 2>&1
