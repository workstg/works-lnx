#!/bin/bash

MYSQL_ROOT_PW=mysql
ABLOG_DB=ablog_db
ABLOG_USER=ablog
ABLOG_PW=ablog
BASE_URL=dev.example.com
DOC_ROOT=/var/www/html
PAC_DIR=/tmp/packages

[ -d ${PAC_DIR} ] && rm -rf ${PAC_DIR}
mkdir ${PAC_DIR}
cd ${PAC_DIR}
if [ ! -f ${PAC_DIR}/acms250_install.zip ]; then
   echo "Download a-blog cms v2.7.12 Installer (php5.4.x+ Edition)"
   wget https://developer.a-blogcms.jp/_package/2.7.12/acms2.7.12_php5.3.zip
   if [ ! -f ${PAC_DIR}/acms2.7.12_php5.3.zip ]; then
      echo 'a-blog cms not found!'
      exit 1
   fi
fi
if [ ! -f ${PAC_DIR}/ioncube_loaders_lin_x86-64.tar.gz ]; then
   echo "Download ionCube Loader for Linux x86_64"
   wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
   if [ ! -f ${PAC_DIR}/ioncube_loaders_lin_x86-64.tar.gz ]; then
      echo 'ionCube Loader not found!'
      exit 1
   fi
fi

sed -i "s/SELINUX\=.*/SELINUX\=permissive/" /etc/selinux/config
yum -y install epel-release unzip

# MariaDB Package
cat <<EOF > /etc/yum.repos.d/MariaDB.repo
# MariaDB 10.2 CentOS repository list - created 2017-06-02 06:31 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
yum -y install MariaDB-server MariaDB-client

# Apache + PHP
yum -y install httpd mod_ssl bind-utils php php-{cli,common,mbstring,pdo,xml,mysqlnd,pecl-apcu,xmlrpc,opcache,gd}
yum -y update

# MariaDB Setup
cp -p /etc/my.cnf.d/server.conf /etc/my.cnf.d/server.conf.org
cat <<EOF > /etc/my.cnf.d/server.conf
[server]

[mysqld]
symbolic-links=0
default-storage-engine = InnoDB
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 1
innodb_support_xa = 1
character-set-server = utf8
query_cache_size = 0
query_cache_type = 0
query_cache_limit = 64M
#performance_schema = ON
join_buffer_size = 2M
innodb_buffer_pool_size = 256M
innodb_log_files_in_group = 2
innodb_log_file_size = 32M

[galera]

[embedded]

[mariadb]

[mariadb-10.1]

EOF



systemctl enable mariadb.service
systemctl start mariadb.service

mysqladmin -u root password ${MYSQL_ROOT_PW}
mysql -u root -p${MYSQL_ROOT_PW} <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE test;
FLUSH PRIVILEGES;
EOF

# PHP Setup
cp -p /etc/php.ini /etc/php.ini.org
sed -i "s/\;date\.timezone\ \=/\;date\.timezone\ \=\ndate\.timezone\ \=\ Asia\/Tokyo/" /etc/php.ini

# Apache Setup
cp -p /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.org
cat <<'EOF' > /etc/httpd/conf/httpd.conf
ServerRoot "/etc/httpd"
Listen 80
Include conf.modules.d/*.conf
User apache
Group apache
ServerAdmin root@localhost

<Directory />
    AllowOverride none
    Require all denied
</Directory>

DocumentRoot "/var/www/html"
<Directory "/var/www">
    AllowOverride None
    Require all granted
</Directory>
<Directory "/var/www/html">
    Options All
    AllowOverride All
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html
</IfModule>

<Files ".ht*">
    Require all denied
</Files>

ErrorLog "logs/error_log"
LogLevel warn
<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common
    <IfModule logio_module>
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>
    CustomLog "logs/access_log" combined
</IfModule>

<IfModule alias_module>
    ScriptAlias /cgi-bin/ "/var/www/cgi-bin/"
</IfModule>
<Directory "/var/www/cgi-bin">
    AllowOverride None
    Options None
    Require all granted
</Directory>
<IfModule mime_module>
    TypesConfig /etc/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType text/html .shtml
    AddOutputFilter INCLUDES .shtml
</IfModule>
AddDefaultCharset UTF-8
<IfModule mime_magic_module>
    MIMEMagicFile conf/magic
</IfModule>
EnableSendfile on
IncludeOptional conf.d/*.conf
EOF

# Create Database for a-blog cms
mysql -u root -p${MYSQL_ROOT_PW} <<EOF
CREATE DATABASE ${ABLOG_DB} CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON ${ABLOG_DB}.* TO ${ABLOG_USER}@localhost IDENTIFIED BY '${ABLOG_PW}';
FLUSH PRIVILEGES;
EOF

# Install ionCube Modules
cd ${PAC_DIR}
tar -zxvf ./ioncube_loaders_lin_x86-64.tar.gz
cp -p ./ioncube/ioncube_loader_lin_5.4.so /usr/lib64/php/modules/
cat <<EOF > /etc/php.d/00-ioncube.ini
zend_extension = /usr/lib64/php/modules/ioncube_loader_lin_5.4.so
EOF

# Deploy a-blog cms
cd ${PAC_DIR}
unzip ./acms2.7.12_php5.3.zip
mv ./acms2.7.12_php5.3/ablogcms/* ${DOC_ROOT}/
cd ${DOC_ROOT}
chmod 666 ./config.server.php
chmod 777 ./archives
chmod 777 ./archives_rev
chmod 777 ./media
chmod 777 ./cache
chmod 777 ./themes
mv ./htaccess.txt ./.htaccess
mv ./archives/htaccess.txt ./archives/.htaccess
mv ./archives_rev/htaccess.txt ./archives_rev/.htaccess
mv ./media/htaccess.txt ./media/.htaccess
mv ./cache/htaccess.txt ./cache/.htaccess
mv ./private/htaccess.txt ./private/.htaccess
mv ./themes/htaccess.txt ./themes/.htaccess

# Open HTTP Port
firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --add-service=https --zone=public --permanent
firewall-cmd --reload

systemctl enable httpd.service
systemctl start httpd.service

echo "Prease access to \"http://${BASE_URL}/\"."

exit

