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
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
add-apt-repository -y ppa:ondrej/apache2 > /dev/null 2>&1

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get -y install php5.6 php5.6-mcrypt php5.6-mbstring php5.6-curl php5.6-cli php5.6-mysql php5.6-gd php5.6-intl php5.6-xsl php5.6-xdebug php5.6-tidy apache2 libapache2-mod-php5.6 > /dev/null 2>&1

echo -e "\n--- Install MySQL specific packages and settings ---\n"
echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get -y install mysql-server-5.5 phpmyadmin > /dev/null 2>&1

echo -e "\n--- Enabling mod-rewrite ---\n"
a2enmod rewrite > /dev/null 2>&1

echo -e "\n--- Allowing Apache override to all ---\n"
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

echo -e "\n--- We definitly need to see the PHP errors, turning them on ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/5.6/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/5.6/apache2/php.ini
sed -i "s/memory_limit = .*/memory_limit = 1G/" /etc/php/5.6/apache2/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" /etc/php/5.6/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 32M/" /etc/php/5.6/apache2/php.ini


a2dissite default > /dev/null 2>&1
a2dissite default-ssl > /dev/null 2>&1
service apache2 restart > /dev/null 2>&1

rm -f /etc/apache2/sites-available/*
rm -f /etc/apache2/sites-enabled/*

echo -e "\n--- Configure Apache to use phpmyadmin ---\n"
cat > /etc/apache2/ports.conf <<EOF
Listen 80
Listen 81
Listen 82
Listen 83

<IfModule mod_ssl.c>
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

cat > /etc/apache2/sites-available/phpmyadmin.conf <<EOF
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
cat > /etc/apache2/sites-available/default.conf <<EOF
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
cat > /etc/apache2/sites-available/drupal.conf <<EOF
<VirtualHost *:82>
    DocumentRoot /var/www/drupal
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
if [ ! -d "/var/www/drupal" ]; then
  mysql -uroot -p$DBPASSWD -e "CREATE DATABASE drupal CHARSET utf8"
  cd /var/www
  wget https://ftp.drupal.org/files/projects/drupal-8.1.10.tar.gz > /dev/null 2>&1
  tar xzf drupal-8.1.10.tar.gz > /dev/null 2>&1
  mv drupal-8.1.10 drupal
  rm -f drupal-8.1.10.tar.gz
  mkdir drupal/sites/default/files
  chmod -R 777 drupal/sites/default/files
fi
a2ensite drupal > /dev/null 2>&1


echo -e "\n--- Creating Drupal 7 site ---\n"
cat > /etc/apache2/sites-available/drupal7.conf <<EOF
<VirtualHost *:83>
    DocumentRoot /var/www/drupal7
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
if [ ! -d "/var/www/drupal7" ]; then
  mysql -uroot -p$DBPASSWD -e "CREATE DATABASE drupal7 CHARSET utf8"
  cd /var/www
  wget https://ftp.drupal.org/files/projects/drupal-7.50.tar.gz > /dev/null 2>&1
  tar xzf drupal-7.50.tar.gz > /dev/null 2>&1
  mv drupal-7.50 drupal7
  rm -f drupal-7.50.tar.gz
  mkdir drupal7/sites/default/files
  chmod -R 777 drupal7/sites/default/files
fi
a2ensite drupal7 > /dev/null 2>&1

echo -e "\n--- Restarting Apache ---\n"
service apache2 restart > /dev/null 2>&1
