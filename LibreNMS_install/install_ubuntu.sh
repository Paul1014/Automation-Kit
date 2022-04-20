#Install packages
echo "
----------------
install packages
----------------
"
sudo apt -y install software-properties-common
sudo add-apt-repository universe
sudo apt -y update
sudo apt -y install apache2 acl curl composer fping git graphviz imagemagick mariadb-client mariadb-server mtr-tiny nginx-full nmap php7.4-cli php7.4-curl php7.4-fpm php7.4-gd php7.4-gmp php7.4-json php7.4-mbstring php7.4-mysql php7.4-snmp php7.4-xml php7.4-zip rrdtool snmp snmpd whois unzip python3-pymysql python3-dotenv python3-redis python3-setuptools python3-systemd python3-pip

#Create user
echo "
----------------
Create user
----------------
"
sudo useradd librenms -d /opt/librenms -M -r -s "$(which bash)"

echo "done"
#Download LibreNMS
echo "
----------------
Download LibreNMS
----------------
"
cd /opt
git clone https://github.com/librenms/librenms.git

echo "done"
#Set Permissions
echo "
----------------
Set Permissions
----------------
"
sudo chown -R librenms:librenms /opt/librenms
sudo chmod 771 /opt/librenms
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
sudo setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
echo "done"
#Install PHP dependencies
echo "
----------------
Install PHP dependencies
----------------
"
sudo su librenms -c "php /opt/librenms/scripts/composer_wrapper.php install --no-dev"


echo "done"
#set php timezone
echo "
----------------
set php timezone
----------------
"
sudo echo date.timezone = \"Asia/Taipei\" >> /etc/php/7.4/fpm/php.ini
sudo echo date.timezone = \"Asia/Taipei\" >> /etc/php/7.4/cli/php.ini

#set system time zone
sudo timedatectl set-timezone Asia/Taipei

echo "done"
#Configure MariaDB
echo "
----------------
Configure MariaDB
----------------
"
sudo sed -i '/\[server\]/a default-time-zone=+08:00' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i '/\[mysqld\]/a innodb_file_per_table=1' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i '/\[mysqld\]/a lower_case_table_names=0' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mysql
sudo mysql -uroot <<EOF
	CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
	CREATE USER 'librenms'@'localhost' IDENTIFIED BY 'password';
	GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
	FLUSH PRIVILEGES;
	exit
EOF

echo "done"
#Configure PHP-FPM
echo "
----------------
Configure PHP-FPM
----------------
"
sudo cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/librenms.conf
sudo sed -i 's/\[www\]/\[librenms\]/g' /etc/php/7.4/fpm/pool.d/librenms.conf
sudo sed -i 's/user \= www-data/user = librenms/g' /etc/php/7.4/fpm/pool.d/librenms.conf
sudo sed -i 's/group \= www-data/group = librenms/g' /etc/php/7.4/fpm/pool.d/librenms.conf
sudo sed -i 's/php\/php7.4-fpm.sock/php-fpm-librenms.sock/g' /etc/php/7.4/fpm/pool.d/librenms.conf

sudo systemctl restart php7.4-fpm
echo "done"
# Weber server
echo "
----------------
Web Server config
----------------
"

sudo echo "<VirtualHost *:80>
  DocumentRoot /opt/librenms/html/
  ServerName  librenms.example.com

  AllowEncodedSlashes NoDecode
  <Directory \"/opt/librenms/html/\">
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>

  # Enable http authorization headers
  <IfModule setenvif_module>
    SetEnvIfNoCase ^Authorization$ \"(.+)\" HTTP_AUTHORIZATION=\$1
  </IfModule>

  <FilesMatch \".+\.php$\">
    SetHandler \"proxy:unix:/run/php-fpm-librenms.sock|fcgi://localhost\"
  </FilesMatch>
</VirtualHost>" > /etc/apache2/sites-available/librenms.conf

sudo a2dissite 000-default
sudo a2enmod proxy_fcgi setenvif rewrite
sudo a2ensite librenms.conf
sudo systemctl restart apache2
sudo systemctl restart php7.4-fpm
echo "done"
#Enable lnms
echo "
----------------
Enable Lnms
----------------
"
sudo ln -s /opt/librenms/lnms /usr/bin/lnms
sudo cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/

echo "done"
#Cron job
echo "
----------------
Cron job
----------------
"
sudo cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
echo "done"
#Copy logrotate config
echo "
----------------
Copy logrotate config
----------------
"
sudo cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

echo "Install libreNMS is complete, please browse the web page"