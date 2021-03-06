#!/bin/bash

ZBX_USER="zabbix"
ZBX_PASS="zabbix"
ZBX_DB="zabbix"
MYSQL_RC="/root/mysqlrc_root"

cd /usr/local/src

# Package Install
yum -y update
yum -y install epel-release
rpm -ivh http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
yum -y install httpd mariadb mariadb-server zabbix-server-mysql zabbix-web-mysql zabbix-agent snmptt perl-Sys-Syslog net-snmp-perl net-snmp-utils

# Disable SE Linux
sed -i 's/SELINUX\=enforcing/SELINUX=permissive/' /etc/selinux/config
setenforce 0

# Starting Database Service
systemctl start mariadb
systemctl enable mariadb

# Create Database and User for Zabbix
echo "user root $(cat /dev/urandom | tr -dc '[:alnum:]' | head -c 8)" > ${MYSQL_RC}
MYSQLPW=$(grep ^user ${MYSQL_RC} | awk '{print $NF}')

mysqladmin -u root password "${MYSQLPW}"
mysql -u root -p${MYSQLPW} -e "CREATE DATABASE ${ZBX_DB} CHARACTER SET utf8;"
mysql -u root -p${MYSQLPW} -e "CREATE USER '${ZBX_USER}'@'localhost' IDENTIFIED BY '${ZBX_PASS}';"
mysql -u root -p${MYSQLPW} -e "GRANT ALL PRIVILEGES ON ${ZBX_DB}.* TO '${ZBX_USER}'@'localhost';"

ZBX_SQL_PATH="/usr/share/doc/zabbix-server-mysql-$(rpm -q --qf '%{version}' zabbix-server-mysql)"
cp -p ${ZBX_SQL_PATH}/create.sql.gz ./
gunzip ./create.sql.gz
mysql -u ${ZBX_USER} -p${ZBX_PASS} ${ZBX_DB} < create.sql

# PHP Configure
cp -p /etc/php.ini /etc/php.ini.org
sed -i 's/^max_execution_time.*/max_execution_time = 600/' /etc/php.ini
sed -i 's/^max_input_time.*/max_input_time = 600/' /etc/php.ini
sed -i 's/^memory_limit.*/memory_limit = 256M/' /etc/php.ini
sed -i 's/^post_max_size.*/post_max_size = 32M/' /etc/php.ini
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 16M/' /etc/php.ini
sed -i "s/^\;date.timezone.*/date.timezone = \'Asia\/Tokyo\'/" /etc/php.ini

# Zabbix Server Configure
cp -p /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.org
sed -i "s/^DBName=.*/DBName=${ZBX_DB}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBUser=.*/DBUser=${ZBX_USER}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=.*/# DBPassword=\nDBPassword=${ZBX_PASS}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# StartSNMPTrapper=.*/# StartSNMPTrapper=\nStartSNMPTrapper=1/" /etc/zabbix/zabbix_server.conf

# SNMPTT Configure
cp -p /etc/snmp/snmptrapd.conf /etc/snmp/snmptrapd.conf.org
cat <<EOF >> /etc/snmp/snmptrapd.conf
#authCommunity   log,execute,net public
disableAuthorization yes
perl do "/usr/share/snmptt/snmptthandler-embedded";
EOF
cat <<EOF > /etc/snmp/generaltrap.conf
#
# General Event
#
EVENT general .* "General event" Normal
FORMAT ZBXTRAP $aA $ar $1
#
EOF

cp -p /etc/snmp/snmptt.conf /etc/snmp/snmptt.conf.org
sed -i 's/^FORMAT\s/FORMAT ZBXTRAP \$aA /g' /etc/snmp/snmptt.conf

cp -p /etc/snmp/snmptt.ini /etc/snmp/snmptt.ini.org
sed -i 's/^\#date_time_format\s\=.*/\#date_time_format =\ndate_time_format = %H:%M:%S %Y\/%m\/%d/' /etc/snmp/snmptt.ini
sed -i 's/syslog_enable\s=\s1/syslog_enable = 0/' /etc/snmp/snmptt.ini
sed -i 's/^\/etc\/snmp\/snmptt\.conf$/\/etc\/snmp\/snmptt\.conf\n\/etc\/snmp\/generaltrap\.conf/' /etc/snmp/snmptt.ini

echo "OPTIONS=\"-m +ALL -Lsd -On\"" >> /etc/sysconfig/snmptrapd

# Starting Zabbix Server
systemctl daemon-reload
systemctl start snmptrapd
systemctl start snmptt
systemctl start zabbix-server
systemctl start zabbix-agent
systemctl start httpd

systemctl enable snmptrapd
systemctl enable snmptt
systemctl enable zabbix-server
systemctl enable zabbix-agent
systemctl enable httpd

# Firewall Configure
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=zabbix-server
firewall-cmd --permanent --zone=public --add-service=zabbix-agent
firewall-cmd --permanent --zone=public --add-service=snmp
firewall-cmd --permanent --zone=public --add-service=snmptrap
firewall-cmd --reload

exit
