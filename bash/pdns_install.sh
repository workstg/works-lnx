#!/bin/bash

PDNS_USER="powerdns"
PDNS_PASS="powerdns"
PDNS_DB="powerdns"
MYSQL_RC="/root/mysqlrc_root"
EXTERNAL_IP=$(ip a show | grep inet[^6] | sed -e '2!d' -e "s/.*inet \(.*\)\/.*/\1/")

cd /usr/local/src

# Package Install
rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-2.noarch.rpm
rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum -y update
yum -y install pdns pdns-backend-mysql pdns-recursor pdns-tools mariadb-server bind-utils wget httpd php php-cli php-pdo php-mysql php-mcrypt

# Starting Database Service
systemctl start mariadb
systemctl enable mariadb

# Create Database and User
echo "user root $(cat /dev/urandom | tr -dc '[:alnum:]' | head -c 8)" > ${MYSQL_RC}
mysqladmin -u root password "$(grep ^user ${MYSQL_RC} | awk '{print $NF}')"
mysql -u root -p$(grep ^user ${MYSQL_RC} | awk '{print $NF}') -e "CREATE DATABASE ${PDNS_DB} CHARACTER SET utf8;"
mysql -u root -p$(grep ^user ${MYSQL_RC} | awk '{print $NF}') -e "CREATE USER '${PDNS_USER}'@'localhost' IDENTIFIED BY '${PDNS_PASS}';"
mysql -u root -p$(grep ^user ${MYSQL_RC} | awk '{print $NF}') -e "GRANT ALL PRIVILEGES ON ${PDNS_DB}.* TO '${PDNS_USER}'@'localhost';"

# Create Table
mysql -u${PDNS_USER} -p${PDNS_PASS} ${PDNS_DB} <<EOF
CREATE TABLE domains (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT DEFAULT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB;
CREATE UNIQUE INDEX name_index ON domains(name);
CREATE TABLE records (
  id                    INT AUTO_INCREMENT,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(64000) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  change_date           INT DEFAULT NULL,
  disabled              TINYINT(1) DEFAULT 0,
  ordername             VARCHAR(255) BINARY DEFAULT NULL,
  auth                  TINYINT(1) DEFAULT 1,
  PRIMARY KEY (id)
) Engine=InnoDB;
CREATE INDEX nametype_index ON records(name,type);
CREATE INDEX domain_id ON records(domain_id);
CREATE INDEX recordorder ON records (domain_id, ordername);
CREATE TABLE supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) NOT NULL,
  PRIMARY KEY (ip, nameserver)
) Engine=InnoDB;
CREATE TABLE comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) NOT NULL,
  comment               VARCHAR(64000) NOT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB;
CREATE INDEX comments_domain_id_idx ON comments (domain_id);
CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);
CREATE TABLE domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  PRIMARY KEY (id)
) Engine=InnoDB;
CREATE INDEX domainmetadata_idx ON domainmetadata (domain_id, kind);
CREATE TABLE cryptokeys (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  content               TEXT,
  PRIMARY KEY(id)
) Engine=InnoDB;
CREATE INDEX domainidindex ON cryptokeys(domain_id);
CREATE TABLE tsigkeys (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255),
  algorithm             VARCHAR(50),
  secret                VARCHAR(255),
  PRIMARY KEY (id)
) Engine=InnoDB;
CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
EOF

# Configure PowerDNS
cp -p /etc/pdns/pdns.conf /etc/pdns/pdns.conf.org
cat <<EOF > /etc/pdns/pdns.conf
setuid=pdns
setgid=pdns
local-address=127.0.0.1
recursor=8.8.8.8
launch=gmysql
gmysql-host=localhost
gmysql-user=${PDNS_USER}
gmysql-password=${PDNS_PASS}
gmysql-dbname=${PDNS_DB}
gmysql-dnssec=yes
EOF

# Starting PowerDNS Service
systemctl start pdns.service
systemctl enable pdns.service

# Configure PowerDNS Recursor
cp -p /etc/pdns-recursor/recursor.conf /etc/pdns-recursor/recursor.conf.org
cat <<EOF > /etc/pdns-recursor/recursor.conf
setuid=pdns-recursor
setgid=pdns-recursor
local-address=${EXTERNAL_IP}
allow-from=allow-from=127.0.0.0/8, 10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12
forward-zones-recurse=.=127.0.0.1
EOF

# Starting PowerDNS Recursor
systemctl start pdns-recursor.service
systemctl enable pdns-recursor.service

# Install and Configure Poweradmin
wget http://downloads.sourceforge.net/project/poweradmin/poweradmin-2.1.7.tgz
tar -zxvf ./poweradmin-2.1.7.tgz
mv ./poweradmin-2.1.7/inc/config-me.inc.php ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_host.*/\$db_host = \'localhost\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_port.*/\$db_port = \'3306\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_user.*/\$db_user = \'${PDNS_USER}\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_pass.*/\$db_pass = \'${PDNS_PASS}\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_name.*/\$db_name = \'${PDNS_DB}\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
sed -i "s/\$db_type.*/\$db_type = \'mysql\'\;/" ./poweradmin-2.1.7/inc/config.inc.php
mkdir -p /var/www/html/poweradmin
mv ./poweradmin-2.1.7/* /var/www/html/poweradmin

# Starting Apache Web Server
systemctl start httpd.service
systemctl enable httpd.service

# Next Step : Access to http://$(hostname)/poweradmin/install"
# $session_key should be changed upon install (Target file : /var/www/html/poweradmin/inc/config.inc.php)

exit
