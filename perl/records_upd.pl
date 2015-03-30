#!/usr/bin/perl
# PowerDNSのAレコードをアップデートするサンプルスクリプト
use strict;
use warnings;
use DBI;

my ($i, $dbh, $sth, $ret, $rows, $id_soa, $id_a, $cont_soa, $cont_a);
my ($name_server, $hostmaster, $serial, $refresh, $retry, $expire, $ttl);
my @result;

# ゾーン情報
my $tgt_domain = "example.com";   # 対象ゾーン名
my $ip_before = "192.168.0.1";    # 更新前のAレコードのIPアドレス
my $ip_after = "192.168.0.10";    # 更新後のAレコードのIPアドレス

# DBアクセス情報
my $data_source = 'DBI:mysql:powerdns';
my $user = 'powerdns';
my $pass = 'powerdns';

# DBに接続
$dbh = DBI->connect($data_source, $user, $pass) or die $DBI::errstr;

# SOAレコードを取得
$sth = $dbh->prepare("SELECT records.id,records.content FROM records INNER JOIN domains ON records.domain_id = domains.id WHERE domains.name = '$tgt_domain' AND records.type = 'SOA';");
$ret = $sth->execute;
$rows = $sth->rows;
for ($i=0; $i<$rows; $i++){
   @result = $sth->fetchrow_array;
   $id_soa = $result[0];
   $cont_soa = $result[1];
}

# Aレコードを取得
$sth = $dbh->prepare("SELECT records.id FROM records INNER JOIN domains ON records.domain_id = domains.id WHERE domains.name = '$tgt_domain' AND records.content = '$ip_before' AND records.type = 'A';");
$ret = $sth->execute;
$rows = $sth->rows;
for ($i=0; $i<$rows; $i++){
   @result = $sth->fetchrow_array;
   $id_a = $result[0];
}

# シリアル値を増加
($name_server, $hostmaster, $serial, $refresh, $retry, $expire, $ttl) = split(/\s+/, $cont_soa);
$serial = $serial + 1;
$cont_soa = "$name_server $hostmaster $serial $refresh $retry $expire $ttl";

# AレコードとSOAレコードをアップデート
$sth = $dbh->prepare("UPDATE records SET content = '$ip_after' WHERE id = $id_a;");
$ret = $sth->execute;

$sth = $dbh->prepare("UPDATE records SET content = '$cont_soa' WHERE id = $id_soa;");
$ret = $sth->execute;

# DBから切断
$dbh->disconnect;

exit(0);
