#!/bin/bash

# 作業ディレクトリ
SRC_DIR="/usr/local/src"
# SambaのダウンロードURL
SAMBA_URL="https://download.samba.org/pub/samba/samba-4.3.2.tar.gz"
# ドメイン名
REALM="EXAMPLE.COM"
# DNSフォワーダ
EXT_DNS="8.8.8.8"
# ドメイン管理者 (Administrator) のパスワード
ADMIN_PASSWORD="PASSW0RD!"

# 必要なパッケージのインストール/アップデート
yum -y update
yum -y install \
   libacl-devel \
   libblkid-devel \
   gnutls-devel \
   readline-devel \
   python-devel \
   gdb \
   pkgconfig \
   krb5-workstation \
   zlib-devel \
   setroubleshoot-server \
   setroubleshoot-plugins \
   policycoreutils-python \
   libsemanage-python \
   setools-libs \
   popt-devel \
   libpcap-devel \
   sqlite-devel \
   libidn-devel \
   libxml2-devel \
   libacl-devel \
   libsepol-devel \
   libattr-devel \
   keyutils-libs-devel \
   cyrus-sasl-devel \
   openldap-devel \
   gnutls-devel \
   m4 \
   perl-Data-Dumper \
   autoconf \
   gcc \
   wget

# Samba 4のダウンロードとビルド
cd $SRC_DIR
wget $SAMBA_URL
tar zxvf samba-4.3.2.tar.gz
cd ./samba-4.3.2
./configure
make && make install

if [ $? -ne 0 ]; then
   echo "Install Error!!!"
   exit 1
fi

# ドメインの初期設定
cd /usr/local/samba
./bin/samba-tool domain provision --use-rfc2307 \
   --realm=$REALM \
   --domain=$(echo $REALM | awk -F '.' '{print $1}') \
   --server-role=dc \
   --dns-backend=SAMBA_INTERNAL \
   --option="dns forwarder"=$EXT_DNS \
   --adminpass=$ADMIN_PASSWORD \
   --function-level=2008_R2

cp -p /usr/local/samba/private/krb5.conf /etc/

# 起動/停止スクリプトの作成
cat <<'EOF' > /etc/rc.d/init.d/samba
#!/bin/bash
#
# samba4        This shell script takes care of starting and stopping
#               samba4 daemons.
#
# chkconfig: - 58 74
# description: Samba 4.0 will be the next version of the Samba suite
# and incorporates all the technology found in both the Samba4 alpha
# series and the stable 3.x series. The primary additional features
# over Samba 3.6 are support for the Active Directory logon protocols
# used by Windows 2000 and above.

### BEGIN INIT INFO
# Provides: samba4
# Required-Start: $network $local_fs $remote_fs
# Required-Stop: $network $local_fs $remote_fs
# Should-Start: $syslog $named
# Should-Stop: $syslog $named
# Short-Description: start and stop samba4
# Description: Samba 4.0 will be the next version of the Samba suite
# and incorporates all the technology found in both the Samba4 alpha
# series and the stable 3.x series. The primary additional features
# over Samba 3.6 are support for the Active Directory logon protocols
# used by Windows 2000 and above.
### END INIT INFO

# Source function library.
. /etc/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

prog=samba
prog_dir=/usr/local/samba/sbin/
lockfile=/var/lock/subsys/$prog

start() {
        [ "$NETWORKING" = "no" ] && exit 1
#       [ -x /usr/sbin/ntpd ] || exit 5

                # Start daemons.
                echo -n $"Starting samba4: "
                daemon $prog_dir/$prog -D
        RETVAL=$?
                echo
        [ $RETVAL -eq 0 ] && touch $lockfile
        return $RETVAL
}

stop() {
        [ "$EUID" != "0" ] && exit 4
                echo -n $"Shutting down samba4: "
        killproc $prog_dir/$prog
        RETVAL=$?
                echo
        [ $RETVAL -eq 0 ] && rm -f $lockfile
        return $RETVAL
}

# See how we were called.
case "$1" in
start)
        start
        ;;
stop)
        stop
        ;;
status)
        status $prog
        ;;
restart)
        stop
        start
        ;;
reload)
        echo "Not implemented yet."
        exit 3
        ;;
*)
        echo $"Usage: $0 {start|stop|status|restart|reload}"
        exit 2
esac
EOF

# サービスへの登録
chmod +x /etc/rc.d/init.d/samba
chkconfig --add samba
chkconfig samba on
chkconfig --list | grep samba

# サービス開始
service samba start

exit