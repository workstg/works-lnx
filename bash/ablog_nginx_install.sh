#!/bin/bash

MYSQL_ROOT_PW=mysql
ABLOG_DB=ablog_db
ABLOG_USER=ablog
ABLOG_PW=ablog
BASE_URL=dev.workstg.biz
DOC_ROOT=/var/www/dev
PAC_DIR=/tmp/packages

[ -d ${PAC_DIR} ] && rm -rf ${PAC_DIR}
mkdir ${PAC_DIR}
cd ${PAC_DIR}
if [ ! -f ${PAC_DIR}/acms2114_install.zip ]; then
   echo "Download a-blog cms v2.1.1.4 Installer (php5.5.x+ Edition)"
   wget http://www.a-blogcms.jp/_download/2114/55/acms2114_install.zip
   if [ ! -f ${PAC_DIR}/acms2114_install.zip ]; then
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

# Nginx Package
rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
cp -p /etc/yum.repos.d/nginx.repo /etc/yum.repos.d/nginx.repo.org
sed -i 's/centos/mainline\/centos/' /etc/yum.repos.d/nginx.repo
yum -y install nginx

# PHP 5.6 Install
rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum --enablerepo=remi,remi-php56 -y install php-cli php-common php-mbstring php-pdo php-xml php-mysqlnd php-pecl-apcu php-xmlrpc php-opcache php-fpm php-gd

# MariaDB Package
yum -y install mariadb mariadb-server

# MariaDB Setup
systemctl start mariadb
systemctl enable mariadb

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
cp -p /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.org
sed -i "s/^user\ \= apache/\;user\ \= apache\nuser\ \=\ nginx/" /etc/php-fpm.d/www.conf
sed -i "s/^group\ \= apache/\;group\ \= apache\ngroup\ \=\ nginx/" /etc/php-fpm.d/www.conf
chown nginx:root /var/log/php-fpm
systemctl start php-fpm
systemctl enable php-fpm

# Nginx Setup
cp -p /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org
sed -i "s/worker_processes[[:space:]]\+[0-9]\+/worker_processes $(cat /proc/cpuinfo | grep processor | wc -l)/g" /etc/nginx/nginx.conf
cat <<EOF > /etc/nginx/conf.d/${BASE_URL}.conf
server {
   listen 80;
   server_name ${BASE_URL};

   root ${DOC_ROOT};
   index index.html index.php;
   charset utf-8;

   access_log /var/log/nginx/${BASE_URL}-access.log;
   error_log /var/log/nginx/${BASE_URL}-error.log;

   location / {
      if (-e \$request_filename) { break; }
      rewrite (.*(^|/)[^\./]+)\$ \$1/ permanent;
      rewrite ((\.(html|htm|php|xml|txt|js|json|css|yaml|csv))|/)\$ /index.php last;
   }

   location ~ \.php\$ {
      fastcgi_split_path_info ^(.+\.php)(.*)\$;
      fastcgi_pass 127.0.0.1:9000;
      fastcgi_index index.php;
      include /etc/nginx/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_param PAHT_INFO \$fastcgi_script_name;
      fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
   }
}
EOF

mkdir -p ${DOC_ROOT}
chown -R nginx:root ${DOC_ROT}
chmod -R g+x ${DOC_ROOT}
chown -R root:nginx /var/lib/php/session
chown -R root:nginx /var/lib/php/wsdlcache
systemctl start nginx
systemctl enable nginx

# Create Database for a-blog cms
mysql -u root -p${MYSQL_ROOT_PW} <<EOF
CREATE DATABASE ${ABLOG_DB} CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON ${ABLOG_DB}.* TO ${ABLOG_USER}@localhost IDENTIFIED BY '${ABLOG_PW}';
FLUSH PRIVILEGES;
EOF

# Install ionCube Modules
cd ${PAC_DIR}
tar -zxvf ./ioncube_loaders_lin_x86-64.tar.gz
cp -p ./ioncube/ioncube_loader_lin_5.6.so /usr/lib64/php/modules/
cat <<EOF > /etc/php.d/00-ioncube.ini
zend_extension = /usr/lib64/php/modules/ioncube_loader_lin_5.6.so
EOF
systemctl restart php-fpm

# Deploy a-blog cms
cd ${PAC_DIR}
unzip ./acms2114_install.zip
mv ./release-2114_install/ablogcms/* ${DOC_ROOT}/
chown -R nginx:root ${DOC_ROOT}
cd ${DOC_ROOT}
chmod 666 ./config.server.php
chmod 777 ./archives
chmod 777 ./archives_rev
chmod 777 ./media
chmod 777 ./themes
mv ./htaccess.txt ./.htaccess
mv ./archives/htaccess.txt ./archives/.htaccess
mv ./private/htaccess.txt ./private/.htaccess
mv ./themes/htaccess.txt ./themes/.htaccess

# Open HTTP Port
firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --add-service=https --zone=public --permanent
firewall-cmd --reload

echo "Prease access to \"http://${BASE_URL}/\"."

exit

