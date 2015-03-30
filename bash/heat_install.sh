#!/bin/bash
HEAT_HOST="192.168.40.91"
IDEN_HOST="192.168.40.91"
REGION="RegionOne"
MYSQL_PW="mysql"
HEAT_PW="heat"

# パッケージインストール
yum -y install openstack-heat-* python-heatclient openstack-utils

# データベース作成
mysql -uroot -p${MYSQL_PW} <<EOF
CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY '${HEAT_PW}';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '${HEAT_PW}';
FLUSH PRIVILEGES;
EOF

# データベース初期設定
crudini --set /etc/heat/heat.conf DEFAULT sql_connection mysql://heat:${HEAT_PW}@localhost/heat
runuser -s /bin/sh heat -c "heat-manage db_sync"

# API バインドアドレス
crudini --set /etc/heat/heat.conf heat_api bind_host ${HEAT_HOST}
crudini --set /etc/heat/heat.conf heat_api_cfn bind_host ${HEAT_HOST}
crudini --set /etc/heat/heat.conf heat_api_cloudwatch bind_host ${HEAT_HOST}

# Keystone 設定
. /root/keystonerc_admin
keystone user-create --name=heat --pass=${HEAT_PW}
keystone user-role-add --user heat --role admin --tenant services
keystone service-create --name heat --type orchestration
keystone service-create --name heat-cfn --type cloudformation

HEAT_ID=$(keystone service-list | awk '/orchestration/ {print $2}')
CFN_ID=$(keystone service-list | awk '/cloudformation/ {print $2}')

keystone endpoint-create --region ${REGION} \
   --service heat-cfn \
   --publicurl "http://${HEAT_HOST}:8000/v1" \
   --adminurl "http://${HEAT_HOST}:8000/v1" \
   --internalurl "http://${HEAT_HOST}:8000/v1"

keystone endpoint-create --region ${REGION} \
   --service heat \
   --publicurl "http://${HEAT_HOST}:8004/v1/%(tenant_id)s" \
   --adminurl "http://${HEAT_HOST}:8004/v1/%(tenant_id)s" \
   --internalurl "http://${HEAT_HOST}:8004/v1/%(tenant_id)s"

# Identity Service ドメイン
yum -y install python-openstackclient
ADMIN_TOKEN=$(crudini --get /etc/keystone/keystone.conf DEFAULT admin_token)

openstack --os-token $ADMIN_TOKEN --os-url=http://${IDEN_HOST}:5000/v3 --os-identity-api-version=3 \
   domain create heat --description "Owns users and projects created by heat"
DOMAIN_ID=$(openstack --os-token $ADMIN_TOKEN --os-url=http://${IDEN_HOST}:5000/v3 --os-identity-api-version=3 domain list | awk '/heat/ {print $2}')

openstack --os-token $ADMIN_TOKEN --os-url=http://${IDEN_HOST}:5000/v3 --os-identity-api-version=3 \
   user create heat_domain_admin --password ${HEAT_PW} --domain ${DOMAIN_ID} \
   --description "Manages users and projects created by heat"
DOMAIN_ADMIN_ID=$(openstack --os-token $ADMIN_TOKEN --os-url=http://${IDEN_HOST}:5000/v3 --os-identity-api-version=3 user list | awk '/heat_domain_admin/ {print $2}')

openstack --os-token $ADMIN_TOKEN --os-url=http://${IDEN_HOST}:5000/v3 --os-identity-api-version=3 \
   role add --user ${DOMAIN_ADMIN_ID} --domain ${DOMAIN_ID} admin

# 認証設定
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password ${HEAT_PW}
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin ${DOMAIN_ADMIN_ID}
crudini --set /etc/heat/heat.conf DEFAULT stack_user_domain ${DOMAIN_ID}
crudini --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
crudini --set /etc/heat/heat.conf keystone_authtoken admin_user heat
crudini --set /etc/heat/heat.conf keystone_authtoken admin_password ${HEAT_PW}
crudini --set /etc/heat/heat.conf keystone_authtoken service_host ${IDEN_HOST}
crudini --set /etc/heat/heat.conf keystone_authtoken auth_host ${IDEN_HOST}
crudini --set /etc/heat/heat.conf keystone_authtoken auth_uri http://${IDEN_HOST}:35357/v2.0
crudini --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://${IDEN_HOST}:35357/v2.0
crudini --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://${HEAT_HOST}:8000
crudini --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://${HEAT_HOST}:8000/v1/waitcondition
crudini --set /etc/heat/heat.conf DEFAULT heat_watch_server_url http://${HEAT_HOST}:8003
crudini --set /etc/heat/heat.conf DEFAULT heat_stack_user_role heat_stack_user

# RabbitMQ
crudini --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_kombu
crudini --set /etc/heat/heat.conf DEFAULT rabbit_host ${HEAT_HOST}
crudini --set /etc/heat/heat.conf DEFAULT rabbit_port 5672
crudini --set /etc/heat/heat.conf DEFAULT rabbit_userid guest
crudini --set /etc/heat/heat.conf DEFAULT rabbit_password guest

# サービス開始
for SERVICE in api api-cfn api-cloudwatch engine
do
   systemctl start openstack-heat-${SERVICE}
   systemctl enable openstack-heat-${SERVICE}
   sleep 1
   systemctl status openstack-heat-${SERVICE}
done
openstack-service status
openstack-status

exit
