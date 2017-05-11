#!/bin/bash

# InstaPress
# One Click WordPress Installer

# Perform Pre-Install Checks
function package_exists() {
    return dpkg -l "$1" &> /dev/null
}

if [  -f /var/www/html/index.php ]; then
    echo "Already exist /var/www/html/index.php"
    exit
fi

# Install Packages
apt-get update -y
apt-get install apache2 -y 
apt-get install php5-mysql -y
mysql_install_db -y
mysql_secure_installation -y
apt-get install php5 libapache2-mod-php5 php5-mcrypt php5-gd php5-cli php5-common -y
apt-get install php5-curl php5-dbg  php5-xmlrpc php5-fpm php-apc php-pear php5-imap -y
apt-get install php5-pspell php5-dev -y 

# Generate Random Password to use
DATE=$(date +%s)
PASSWORD=$(echo $RANDOM$DATE|sha256sum|base64|head -c 12)
sleep 1
USERNAME=`date +%s|sha256sum|base64|head -c 7`
  
# Configure MySQL
export DEBIAN_FRONTEND=noninteractive
if ! package_exists mysql-server; then
  apt-get -q -y install mysql-server
  mysqladmin -u root password  $PASSWORD
fi

if ! package_exists phpmyadmin ; then
  APP_PASS=$PASSWORD
  ROOT_PASS=$PASSWORD
  APP_DB_PASS=$PASSWORD

  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $APP_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $ROOT_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $APP_DB_PASS" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

  apt-get install -y phpmyadmin
 fi

# Install Mail Utils
apt-get install php-pear 
pear install mail 
pear install Net_SMTP 
pear install Auth_SASL 
pear install mail_mime

if ! package_exists postfix ; then
    debconf-set-selections <<< "postfix postfix/mailname string 'localhost'"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    apt-get install -y postfix
fi

# Change postfix in the php.ini file
send_path=/etc/postfix
sed -i 's@;sendmail_path =@send_path = '${send_path}'@' /etc/php5/apache2/php.ini


phpmemory_limit=256M  
sed -i 's/memory_limit = .*/memory_limit = '${phpmemory_limit}'/' /etc/php5/apache2/php.ini

max_execution_time=300   
sed -i 's/max_execution_time = .*/max_execution_time = '${max_execution_time}'/' /etc/php5/apache2/php.ini

upload_max_filesize=456 
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${upload_max_filesize}'/' /etc/php5/apache2/php.ini

post_max_size=456 
sed -i 's/post_max_size = .*/post_max_size = '${post_max_size}'/' /etc/php5/apache2/php.ini


service postfix restart

service apache2 restart
#/etc/init.d/mysql restart

mysql -uroot -p$PASSWORD <<MYSQL_SCRIPT
CREATE DATABASE $USERNAME;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "MySQL user created."
echo "Username:   $USERNAME"
 


echo "============================================"
echo "A robot is now installing WordPress for you."
echo "============================================"

# Download the latest WordPress Package
wget https://wordpress.org/latest.zip

# Unzip wordpress
unzip latest.zip

# cd to wordpress folder
cd wordpress

# Copy all files to the upper directory
cp -rf . /var/www/html

# Move back to the parent folder
cd /var/www/html

# Remove files from wordpress folder
# Create wp config file
cp wp-config-sample.php wp-config.php

# Set database details with the great perl find and replace
perl -pi -e "s/database_name_here/$USERNAME/g" wp-config.php
perl -pi -e "s/username_here/$USERNAME/g" wp-config.php
perl -pi -e "s/password_here/$PASSWORD/g" wp-config.php

# Set the WP salts
perl -i -pe'
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
  }
  s/put your unique phrase here/salt()/ge
' wp-config.php

# Create uploads folder and set permissions

mkdir wp-content/uploads
chmod 775 wp-content/uploads

# Start the cleaning process
echo "Cleaning..."
cd

# Remove the zip file
rm latest.tar.gz
rm -rf wordpress
# Remove the bash script
rm cmsget.sh

rm -rf /var/www/html/index.html



ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)

echo "========================="
echo        "WordPress"
echo "========================="

echo "URL : http://$ip/"

echo "========================"

echo "Database : http://$ip/phpmyadmin"
echo "Username:   $USERNAME"
echo "Password: $PASSWORD"

echo "========================"




