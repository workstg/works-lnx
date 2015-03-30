#!/bin/sh

TRUST_HOST="172.16.11.0/24"
NW_INTERNAL="172.16.11.0/24"

IP_EXTERNAL=`ifconfig eth0 | grep "inet addr" | sed -e 's/^.*addr\:\(.*\)\sBcast.*$/\1/g'`
IP_INTERNAL=`ifconfig eth1 | grep "inet addr" | sed -e 's/^.*addr\:\(.*\)\sBcast.*$/\1/g'`

# フォーワードの許可
echo 1 > /proc/sys/net/ipv4/ip_forward

# 既存構成をフラッシュ
iptables -F
iptables -t nat -F
iptables -X

# デフォルトルール
iptables -P INPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -P OUTPUT ACCEPT

iptables -P FORWARD DROP
iptables -A FORWARD -i eth1 -o eth0 -s $NW_INTERNAL -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# ループバックルールの定義
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ICMP (指定ホスト～内部ネットワークのみ)
iptables -A INPUT -p icmp --icmp-type echo-request -s $TRUST_HOST -d $IP_INTERNAL -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply  -s $IP_INTERNAL -d $TRUST_HOST -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-request -s $IP_INTERNAL -d $TRUST_HOST -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -s $TRUST_HOST -d $IP_INTERNAL -j ACCEPT

# SSH (指定ホスト～内部ネットワークのみ)
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 22 -d $TRUST_HOST -j ACCEPT

# WEB (指定ホスト～内部ネットワークのみ)
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 80 -d $TRUST_HOST -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 443 -d $TRUST_HOST -j ACCEPT

# SMTP (指定ホスト～内部ネットワークのみ)
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 25 -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 25 -d $TRUST_HOST -j ACCEPT

# Zabbix (指定ホスト～内部ネットワークのみ)
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 10050 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 10051 -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 10050 -d $TRUST_HOST -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 10051 -d $TRUST_HOST -j ACCEPT

# DNS
iptables -A INPUT -p tcp -m state --state NEW,ESTABLISHED,RELATED -s $TRUST_HOST -d $IP_INTERNAL --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -s $IP_INTERNAL --sport 53 -d $TRUST_HOST -j ACCEPT
iptables -A INPUT -p udp -s $TRUST_HOST -d $IP_INTERNAL --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp -s $IP_INTERNAL --sport 53 -d $TRUST_HOST -j ACCEPT

# NTP
iptables -A INPUT -p udp -s $TRUST_HOST -d $IP_INTERNAL --dport 123 -j ACCEPT
iptables -A OUTPUT -p udp -s $IP_INTERNAL --sport 123 -d $TRUST_HOST -j ACCEPT

# SNAT
iptables -t nat -A POSTROUTING -o eth0 -s $NW_INTERNAL -j MASQUERADE

# DNAT (WEB)
WEB_SV='172.16.11.17'
iptables -t nat -A PREROUTING -p tcp -i eth0 -d $IP_EXTERNAL --dport 80 -j DNAT --to-destination $WEB_SV:80
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d $WEB_SV --dport 80 -j ACCEPT

#iptables -t nat -A PREROUTING -p tcp -i eth0 -d $IP_EXTERNAL --dport 443 -j DNAT --to-destination $WEB_SV:443
#iptables -A FORWARD -i eth0 -o eth1 -p tcp -d $WEB_SV --dport 443 -j ACCEPT

# RDP -> 172.16.11.11
RDP_SV='172.16.11.11'
iptables -t nat -A PREROUTING -p tcp -i eth0 -d $IP_EXTERNAL --dport 3389 -j DNAT --to-destination $RDP_SV:3389
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d $RDP_SV --dport 3389 -j ACCEPT

# プライベートアドレスへのアクセスをドロップ
#iptables -A OUTPUT -o eth0 -d 10.0.0.0/8 -j DROP
#iptables -A OUTPUT -o eth0 -d 172.16.0.0/12 -j DROP
#iptables -A OUTPUT -o eth0 -d 192.168.0.0/16 -j DROP
#iptables -A OUTPUT -o eth0 -d 127.0.0.0/8 -j DROP

# ロギング
iptables -N LOGGING
iptables -A LOGGING -j LOG --log-level warning --log-prefix "DROP:" -m limit
iptables -A LOGGING -j DROP
iptables -A INPUT -j LOGGING
iptables -A FORWARD -j LOGGING
# ----------