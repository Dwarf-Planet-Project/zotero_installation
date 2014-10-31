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

echo "add debian wheezy repository"
sed -i '$s,$,\ndeb http://ftp.acc.umu.se./debian wheezy-backports main,'  /etc/apt/sources.list

echo "update package cache"
apt-get update

echo "dependencies for dataserver"
apt-get install -y apache2 libapache2-mod-php5 mysql-server memcached zendframework php5-cli php5-memcache php5-mysql php5-curl php5-memcached
apt-get -t wheezy-backports install -y php-aws-sdk php-doctrine-cache

echo "general dependencies"
apt-get install -y git gnutls-bin runit libapache2-modsecurity curl

echo "created required directories"
mkdir -p /srv/zotero/dataserver
# fuck DEBIAN
#mkdir -p /srv/zotero/log/{download,upload,error}
mkdir -p /srv/zotero/log/download
mkdir -p /srv/zotero/log/upload
mkdir -p /srv/zotero/log/error

# save current directory
cur_dir=$(pwd)

echo "download source code of dataserver"
git clone git://github.com/zotero/dataserver.git /srv/zotero/dataserver

echo "download source code of Elastica"
git clone git://github.com/ruflin/Elastica.git /srv/zotero/dataserver/include/Elastica
cd /srv/zotero/dataserver/include/Elastica
git checkout fc607170ab2ca751097648d48a5d38e15e9d5f6a

echo "install add_user script"
cp add_user /srv/zotero/dataserver/admin

echo "patch master.sql"
cp master.sql /srv/zotero/dataserver/misc

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
echo -n "password for zotero database user: "
read zotero_password

cd /srv/zotero/dataserver/misc

DB="mysql -h 127.0.0.1 -P 3306 -u root -p${password}"

echo "DROP DATABASE IF EXISTS zotero_master" | $DB
echo "DROP DATABASE IF EXISTS zotero_shards" | $DB
echo "DROP DATABASE IF EXISTS zotero_ids" | $DB
echo "DROP DATABASE IF EXISTS zotero_www" | $DB

echo "CREATE DATABASE zotero_master" | $DB
echo "CREATE DATABASE zotero_shards" | $DB
echo "CREATE DATABASE zotero_ids" | $DB
echo "CREATE DATABASE zotero_www" | $DB

echo "DROP USER IF EXISTS zotero@localhost;" | $DB

echo "CREATE USER zotero@localhost IDENTIFIED BY '${zotero_password}';" | $DB

echo "GRANT SELECT, INSERT, UPDATE, DELETE ON zotero_master.* TO zotero@localhost;" | $DB
echo "GRANT SELECT, INSERT, UPDATE, DELETE ON zotero_shards.* TO zotero@localhost;" | $DB
echo "GRANT SELECT,INSERT,DELETE ON zotero_ids.* TO zotero@localhost;" | $DB
echo "GRANT SELECT,INSERT,DELETE ON zotero_www.* TO zotero@localhost;" | $DB

echo "Load in master schema"
$DB zotero_master < master.sql
$DB zotero_master < coredata.sql
$DB zotero_master < fulltext.sql

echo "Set up shard info"
echo "INSERT INTO shardHosts VALUES (1, '127.0.0.1', 3306, 'up');" | $DB zotero_master
echo "INSERT INTO shards VALUES (1, 1, 'zotero_shards', 'up', 0);" | $DB zotero_master

echo Load in shard schema
cat shard.sql | $DB zotero_shards
cat triggers.sql | $DB zotero_shards

echo "Load in schema on id server"
cat ids.sql | $DB zotero_ids

echo "Load in www schema"
$DB zotero_www < $(cur_dir)www.sql

echo "Setup roleIDs"
echo "INSERT INTO LUM_ROLE VALUES ('Deleted', 1);" | $DB zotero_www
echo "INSERT INTO LUM_ROLE VALUES ('Invalid', 2);" | $DB zotero_www
echo "INSERT INTO LUM_ROLE VALUES ('Valid', 3);" | $DB zotero_www

echo "#################################"
echo "Configuration database connection"
echo "#################################"
# add code to also configure other databases
cp /srv/zotero/dataserver/include/config/dbconnect.inc.php-sample /srv/zotero/dataserver/include/config/dbconnect.inc.php
echo -n "hostname for database: "
read hostname
sed -i "s/host\ =\ ''/host\ =\ '${hostname}'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/host\ =\ false/host\ =\ '${hostname}'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/port\ =\ ''/port\ =\ 3306/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/port\ =\ false/port\ =\ 3306/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/user\ =\ ''/user\ =\ 'zotero'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/user\ =\ false/user\ =\ 'zotero'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/pass\ =\ ''/pass\ =\ '${zotero_password}'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/pass\ =\ false/pass\ =\ '${zotero_password}'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "8s/db\ =\ ''/db\ =\ 'zotero_master'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "15s/db\ =\ false/db\ =\ 'zotero_shards'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "22s/db\ =\ false/db\ =\ 'zotero_master'/" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/ids/zotero_ids/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php
sed -i "s/'www'/'zotero_www'/g" /srv/zotero/dataserver/include/config/dbconnect.inc.php

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
echo -n "aws access key: "
read AWS_ACCESS_KEY
sed -i "s/AWS_ACCESS_KEY\ =\ ''/AWS_ACCESS_KEY\ =\ '${AWS_ACCESS_KEY}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "aws secret key: "
read AWS_SECRET_KEY
sed -i "s/AWS_SECRET_KEY\ =\ ''/AWS_SECRET_KEY\ =\ '${AWS_SECRET_KEY}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "s3_bucket: "
read S3_BUCKET
sed -i "s/S3_BUCKET\ =\ ''/S3_BUCKET\ =\ '${S3_BUCKET}'/" /srv/zotero/dataserver/include/config/config.inc.php
echo -n "s3 endpoint url: "
read S3_ENDPOINT
sed -i "s/S3_ENDPOINT\ =\ 's3.amazonaws.com'/S3_ENDPOINT\ =\ '${S3_ENDPOINT}'/" /srv/zotero/dataserver/include/config/config.inc.php
read AWS_HOST
sed -i "27a\ \ \ \ \ \ \ \ public static \$AWS_HOST\ =\ '${AWS_HOST};'" /srv/zotero/dataserver/include/config/config.inc.php

sed -i "30i\ \ \ \ \ \ \ \ public static \$URI_PREFIX_DOMAIN_MAP = array(" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "31i\ \ \ \ \ \ \ \ \ \ '\/sync\/' => 'sync'" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "32i\ \ \ \ \ \ \ \ );" /srv/zotero/dataserver/include/config/config.inc.php
sed -i "33i \ " /srv/zotero/dataserver/include/config/config.inc.php

echo -n "memcached servers: "
read MEMCACHED_SERVERS
sed -i "s/'memcached1.localdomain:11211:2',\ 'memcached2.localdomain:11211:1'/'${MEMCACHED_SERVERS}'/" /srv/zotero/dataserver/include/config/config.inc.php

echo "Configure document root folder"
sed -i "s/var\/www\/dataserver/srv\/zotero\/dataserver/" /srv/zotero/dataserver/include/config/config.inc.php

echo "##############################################################"
echo "patch header.inc.php for including host name for using own AWS"
echo "##############################################################"
sed -i "225a \$awsconfig['base_url']\ =\ ZCONFIG::\$AWS_HOST;" /srv/zotero/dataserver/include/header.inc.php

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

