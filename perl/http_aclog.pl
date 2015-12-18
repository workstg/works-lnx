#!/usr/bin/perl

use strict;
use warnings;
use POSIX 'strftime';
use Time::Local 'timelocal';

# 対象のアクセスログ
my $target_log = "/var/log/httpd/access_log";
# 結果の出力先
my $output_log = "/mnt/win/aclog.csv";

# 引数判定（指定フォーマット:YYYYMMDDhhmmss）
my %time;
if(! $ARGV[1]){
   %time = (
      'start'   => tr_epoch(19700101000000),
      'end'     => tr_epoch(20380119031407),
   );
}else{
   %time = (
      'start'   => tr_epoch($ARGV[0]),
      'end'     => tr_epoch($ARGV[1]),
   );
}

# 変数の定義
my (@log_lines, @header, @column);
my (@date, @access_url, @status_code);
my (@dtbl, @refs);
my $csv;
my ($i, $j, $k, $n, $m, $x) = (0, 0, 0, 0, 1, 0);

# Main Routine
# アクセスログの読込
@log_lines = read_log($target_log);

# 必要なデータの取得
while($i <= $#log_lines){
   ($date[$i], $access_url[$i], $status_code[$i]) = log_arrange($log_lines[$i]);
   $date[$i] = tr_epoch(tr_date($date[$i]));
   $i++;
}

# ヘッダー作成
@header = mk_head();
@column = mk_col(@access_url);
open($csv, "> $output_log") or die "Cannot open \"$output_log\"!! : $!\n";
print $csv mk_csv(@header), "\n";

# テーブル作成
while($x <= $#column){
   @{$dtbl[$x]} = ($column[$x], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   $x++;
}

# 指定時間のデータをカウント
while($j <= $#date){
   if(chk_date($date[$j], $time{"start"}, $time{"end"})){
      $n = 0;
      while($n <= $#column){
         $m = 1;
         while($m <= $#header){
            if($access_url[$j] eq $column[$n] and $status_code[$j] eq $header[$m]){
               ${$dtbl[$n]}[$m]++;
            }
            $m++;
         }
         $n++;
      }
   }
   $j++;
}

# CSVファイルの出力
while($k <= $#column){
   print $csv mk_csv(@{$dtbl[$k]}), "\n";
   $k++;
}

# 終了処理
close $csv;
exit(0);

# Sub Routine
# アクセスログの読込
sub read_log{
   my $tgt_log = $_[0];
   my @tmplines;
   my $i = 0;
   
   open(my $fh, "< $tgt_log") or die "Cannot open \"$tgt_log\"!! : $!\n";
   while(<$fh>){
      $tmplines[$i] = $_;
      $i++;
   }
   close $fh;
   chomp(@tmplines);
   return(@tmplines);
}

# ログの整形
sub log_arrange{
   my $logline = $_[0];
   my @tmplist;
   
   @tmplist = ($logline =~ m/^(\S+) (\S+) (\S+) \[(\S+) ([^\]]+)\] "(\S*)(?:\s*(\S*)\s*(\S*))?" (\S+) (\S+) "(.*?)" "(.*?)"/);
   chomp(@tmplist);
   
   return($tmplist[3], $tmplist[6], $tmplist[8]);
}

# 日付の整形
sub tr_date{
   my $tmpline = $_[0];
   my $date;
   my @tmplist;
   my %mm = (
      'Jan' => "01",
      'Feb' => "02",
      'Mar' => "03",
      'Apr' => "04",
      'May' => "05",
      'Jun' => "06",
      'Jul' => "07",
      'Aug' => "08",
      'Sep' => "09",
      'Oct' => "10",
      'Nov' => "11",
      'Dec' => "12",
   );
   
   @tmplist = split(/\/|\:/, $tmpline);
   $date = "$tmplist[2]$mm{$tmplist[1]}$tmplist[0]$tmplist[3]$tmplist[4]$tmplist[5]";
   
   return($date);
}

# ラインヘッダー要素の作成
sub mk_head{
   my @head = (
      "***",
      100,
      101,
      200,
      201,
      202,
      203,
      204,
      205,
      206,
      300,
      301,
      302,
      303,
      304,
      305,
      400,
      401,
      402,
      403,
      404,
      405,
      406,
      407,
      408,
      409,
      410,
      411,
      412,
      413,
      414,
      415,
      500,
      501,
      502,
      503,
      504,
      505,
   );
   return(@head);
}

# カラムヘッダー要素の作成
sub mk_col{
   my @tmplist = @_;
   my %count;
   my @head = grep(!$count{$_}++, @tmplist);
   
   @head = sort(@head);
   return(@head);
}

# 日付・時間の判定
sub chk_date{
   my ($tgt_date, $start, $end) = @_;
   if($tgt_date < $start or $tgt_date > $end){
      return(undef);
   }
   return(1);
}

# CSV形式に整形
sub mk_csv{
   my @tmplist = @_;
   my $tmpline = join(",", @tmplist);
   return($tmpline);
}

# 日時をUnix Epochに変換（YYYYMMDDhhmmss）
sub tr_epoch{
   my $tmpdtm = $_[0];
   my $epoch;
   my (
      $year,
      $manth,
      $day,
      $hour,
      $min,
      $sec
      ) = ($tmpdtm =~ m/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/);
   $year = $year - 1900;
   $manth = $manth - 1;
   
   $epoch = timelocal($sec, $min, $hour, $day, $manth, $year);
   
   return($epoch);
}

__END__
* サブルーチン"log_arrange()"の返り値
 $tmplist[0]   : クライアントのIPアドレス
 $tmplist[1]   : リモートログ
 $tmplist[2]   : クライアント側のユーザー
 $tmplist[3]   : アクセス日時
 $tmolist[4]   : タイムゾーン
 $tmplist[5]   : リクエストメソッド
 $tmplist[6]   : リスエストされたURL
 $tmplist[7]   : プロトコル
 $tmplist[8]   : リクエストに対するHTTPステータスコード
 $tmplist[9]   : 転送データ量（byte）
 $tmplist[10]  : リクエストヘッダに記述されているリファラー
 $tmplist[11]  : リクエストヘッダに記述されているユーザーエージェント

