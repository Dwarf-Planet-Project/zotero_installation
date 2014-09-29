#!/bin/sh

echo "######################################################"
echo "######################################################"
echo "######################################################"
echo "### SCRIPT TO INSTALL ZOTERO WITH MINIMUM EFFORTS ####"
echo "### AUTHOR: PATRICK HÖHN #############################"
echo "### RELEASED UNDER GPLv2 OR LATER ####################"
echo "######################################################"
echo "######################################################"
echo "######################################################"

echo "install required packages"

echo "update package cache"
apt-get update

echo "dependencies for dataserver"
apt-get install -y apache2 libapache2-mod-php5 mysql-server memcached zendframework php5-cli php5-memcache php5-mysql php5-curl 

echo "dependencies for zss"
apt-get install -y uwsgi uwsgi-plugin-psgi libplack-perl libdigest-hmac-perl libjson-xs-perl libfile-util-perl libapache2-mod-uwsgi

echo "general dependencies"
apt-get install -y git gnutls-bin runit

echo "created required directories"
# fuck DEBIAN
#mkdir -p /srv/zotero/{dataserver,zss,storage}
mkdir -p /srv/zotero/dataserver
mkdir -p /srv/zotero/zss
mkdir -p /srv/zotero/storage
# fuck DEBIAN
#mkdir -p /srv/zotero/log/{download,upload,error}
mkdir -p /srv/zotero/log/download
mkdir -p /srv/zotero/log/upload
mkdir -p /srv/zotero/log/error

echo "download source code of dataserver"
git clone git://github.com/sualk/dataserver.git /srv/zotero/dataserver

echo "prepare directory rights"
chown www-data:www-data /srv/zotero/dataserver/tmp

echo "replace zend by native installation"
cd /srv/zotero/dataserver/include
rm -r Zend
ln -s /usr/share/php/Zend/

echo "generate SSL key and cert"
certtool -p --sec-param high --outfile /etc/apache2/zotero.key
certtool -s --load-privkey /etc/apache2/zotero.key --outfile /etc/apache2/zotero.cert

echo "enable ssl support for apache2 server"
a2enmod ssl

echo "enable rewrite support for apache2 server"
a2enmod rewrite

echo "create available site for zotero"
echo "<VirtualHost *:443>
  DocumentRoot /srv/zotero/dataserver/htdocs
  SSLEngine on
  SSLCertificateFile /etc/apache2/zotero.cert
  SSLCertificateKeyFile /etc/apache2/zotero.key

  <Location /zotero/>
    SetHandler uwsgi-handler
    uWSGISocket /var/run/uwsgi/app/zss/socket
    uWSGImodifier1 5
  </Location>

  <Directory "/srv/zotero/dataserver/htdocs/">
    Options FollowSymLinks MultiViews
    AllowOverride All
    Order allow,deny
    Allow from all
  </Directory>

  ErrorLog /srv/zotero/error.log
  CustomLog /srv/zotero/access.log common
</VirtualHost>" > /etc/apache2/sites-available/zotero

echo "activate site for zotero"
a2ensite zotero

echo "change .htaccess"
sed -i '3i RewriteCond %{REQUEST_URI} !^/zotero' /srv/zotero/dataserver/htdocs/.htaccess

echo "restart apache2"
service apache2 reload

echo "###############"
echo "configure MySQL"
echo "###############"
echo " [mysqld]
character-set-server = utf8
collation-server = utf8_general_ci
event-scheduler = ON
sql-mode = STRICT_ALL_TABLES
default-time-zone = '+0:00'" > /etc/mysql/conf.d/zotero.cnf
/etc/init.d/mysql restart
echo -n "root Password for MySQL: "
read password
sed -i "s/PW/${password}/g" /srv/zotero/dataserver/misc/setup_db
echo -n "password for zotero database user: "
read zotero_password
sed -i "s/foobar/${zotero_password}/g" /srv/zotero/dataserver/misc/setup_db
cd /srv/zotero/dataserver/misc/
./setup_db

echo "#################################"
echo "Configuration database connection"
echo "#################################"
cp /srv/zotero/dataserver/include/config/dbconnect.inc.php-sample /srv/zotero/dataserver/include/config/dbconnect.inc.php
echo -n "hostname for database: "
read hostname
sed -i "s/localhost/${hostname}/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/user\ =\ ''/user\ =\ 'zotero'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/pass\ =\ ''/pass\ =\ '${zotero_password}'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "4s/host\ =\ ''/host\ =\ 'localhost'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "6s/db\ =\ ''/db\ =\ 'zotero_master'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "18s/host\ =\ ''/host\ =\ 'localhost'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "25s/host\ =\ ''/host\ =\ 'localhost'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/ids/zotero_ids/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php

echo "###################################"
echo "General configuration of dataserver"
echo "###################################"
cp /srv/zotero/dataserver/include/config/config.inc.php-sample /srv/zotero/dataserver/include/config/config.inc.php

sed -i "s/TESTING_SITE\ =\ true/TESTING_SITE\ =\ false/" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "s/DEV_SITE\ =\ true/DEV_SITE\ =\ false/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "base-uri for zotero api: "
read API_URI
sed -i "s,API_BASE_URI\ =\ '',API_BASE_URI = '${API_URI}'," /srv/zotero/dataserver/include/config/config.inc.php
echo -n "sync domain for zotero: "
read SYNC_DOMAIN
sed -i "s/SYNC_DOMAIN\ =\ ''/SYNC_DOMAIN\ =\ '${SYNC_DOMAIN}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "Salt for passwords: "
read AUTH_SALT
sed -i "s/AUTH_SALT\ =\ ''/AUTH_SALT\ =\ '${AUTH_SALT}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "api super username: " 
read API_SUPER_USERNAME
sed -i "s/API_SUPER_USERNAME\ =\ ''/API_SUPER_USERNAME\ =\ '${API_SUPER_USERNAME}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "api super password: "
read API_SUPER_PASSWORD
sed -i "s/API_SUPER_PASSWORD\ =\ ''/API_SUPER_PASSWORD\ =\ '${API_SUPER_PASSWORD}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "aws secret key: "
read AWS_SECRET_KEY
sed -i "s/AWS_SECRET_KEY\ =\ ''/AWS_SECRET_KEY\ =\ '${AWS_SECRET_KEY}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "s3_bucket: "
read S3_BUCKET
sed -i "s/S3_BUCKET\ =\ ''/S3_BUCKET\ =\ '${S3_BUCKET}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "s3 endpoint url: "
read S3_ENDPOINT
sed -i "s/S3_ENDPOINT\ =\ 's3.amazonaws.com'/S3_ENDPOINT\ =\ '${S3_ENDPOINT}'/" /srv/zotero/dataserver/include/config/config.inc.php

sed -i "30i\ \ \ \ \ \ \ \ public static \$URI_PREFIX_DOMAIN_MAP = array(" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "31i\ \ \ \ \ \ \ \ \ \ '\/sync\/' => 'sync'" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "32i\ \ \ \ \ \ \ \ );" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "33i \ " /srv/zotero/dataserver/include/config/config.inc.php

echo -n "memcached servers: "
read MEMCACHED_SERVERS
sed -i "s/'memcached1.localdomain:11211:2',\ 'memcached2.localdomain:11211:1'/'${MEMCACHED_SERVERS}'/" /srv/zotero/dataserver/include/config/config.inc.php

echo "Configure document root folder"
sed -i "s/var\/www\/dataserver/srv\/zotero\/dataserver/" /srv/zotero/dataserver/include/config/config.inc.php
# echo "configuring zotero start up scripts"
# sed -i "s/processor/dataserver\/processor/" /srv/zotero/dataserver/misc/zotero_download.init
# sed -i "s/processor/dataserver\/processor/" /srv/zotero/dataserver/misc/zotero_error.init
# sed -i "s/processor/dataserver\/processor/" /srv/zotero/dataserver/misc/zotero_upload.init
# 
# echo "configuring start up of zotero scripts"!
# cp /srv/zotero/dataserver/misc/zotero_download.init /etc/init.d/zotero_download
# cp /srv/zotero/dataserver/misc/zotero_error.init /etc/init.d/zotero_error
# cp /srv/zotero/dataserver/misc/zotero_upload.init /etc/init.d/zotero_upload
# 
# echo "add zotero scripts to autostart"
# update-rc.d zotero_download defaults
# update-rc.d zotero_error defaults
# update-rc.d zotero_upload defaults
# 
# echo "start zotero services"
# /etc/init.d/zotero_download start
# /etc/init.d/zotero_error start
# /etc/init.d/zotero_upload start
echo "###############"
echo "Configure runit"
echo "###############"
# because of damned debian split in three commands
# mkdir -p /etc/sv/{zotero-download,zotero-error,zotero-upload}/log
mkdir -p /etc/sv/zotero-download/log
mkdir -p /etc/sv/zotero-error/log
mkdir -p /etc/sv/zotero-upload/log
echo "#!/bin/sh

cd /srv/zotero/dataserver/processor/download
exec 2>&1
exec chpst -u www-data:www-data php5 daemon.php" > /etc/sv/zotero-download/run

echo "#!/bin/sh

cd /srv/zotero/dataserver/processor/error
exec 2>&1
exec chpst -u www-data:www-data php5 daemon.php" > /etc/sv/zotero-error/run

echo "#!/bin/sh

cd /srv/zotero/dataserver/processor/upload
exec 2>&1
exec chpst -u www-data:www-data php5 daemon.php" > /etc/sv/zotero-upload/run

echo "#!/bin/sh

exec svlogd /srv/zotero/log/download" > /etc/sv/zotero-download/log/run

echo "#!/bin/sh

exec svlogd /srv/zotero/log/error" > /etc/sv/zotero-error/log/run

echo "#!/bin/sh

exec svlogd /srv/zotero/log/upload" > /etc/sv/zotero-upload/log/run

chmod +x /etc/sv/zotero-download/run
chmod +x /etc/sv/zotero-error/run
chmod +x /etc/sv/zotero-upload/run
chmod +x /etc/sv/zotero-download/log/run
chmod +x /etc/sv/zotero-error/log/run
chmod +x /etc/sv/zotero-upload/log/run

cd /etc/service
ln -s ../sv/zotero-download /etc/service/
ln -s ../sv/zotero-upload /etc/service/
ln -s ../sv/zotero-error /etc/service/

echo "#############"
echo       ZSS
echo "#############"

echo "download source code for ZSS"
git clone git://github.com/sualk/zss.git /srv/zotero/zss

echo  "adjust path for ZSS.pm"
sed -i "s/path\/to/srv\/zss/" /srv/zotero/zss/zss.psgi

echo "adjust properties in ZSS.pm"
sed -i "s/yoursecretkey/${AWS_SECRET_KEY}/" /srv/zotero/zss/ZSS.pm
sed -i "s/path\/to/srv\/zss/"  /srv/zotero/zss/ZSS.pm

echo "configure uwsgi"
echo "uwsgi:
  plugin: psgi
  psgi: /srv/zotero/zss/zss.psgi" > /etc/uwsgi/apps-available/zss.yaml
ln -s /etc/uwsgi/apps-available/zss.yaml /etc/uwsgi/apps-enabled/zss.yaml
/etc/init.d/uwsgi restart
