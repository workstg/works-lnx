#!/usr/bin/perl

use strict;
use warnings;
use Socket;
use FileHandle;
use POSIX 'strftime';

# 出力先ディレクトリ/ファイル
my $output_dir = "/mnt/win/apache_status";
my $output_log = "$output_dir/apache_status.csv";
my $output_org = "$output_dir/org_log";
chk_dir($output_dir, $output_org);

# アクセス情報
my $host = "localhost";
my $port = 80;
my $path = "/server-status?auto";
my $http = "1.1";

my ($interval, $freq);
if($ARGV[1]){
   ($interval, $freq) = @ARGV;
}else{
   $interval = 10;
   $freq = 1;
}

my ($ip, $sockaddr, $buf, $csv, $txt);
my ($line, $sc_key, $olog, $now, $date, $time);
my (@params, @txtlist);
my $count = 0;

if(! -f $output_log){
   open($csv, "> $output_log") or die "Cannot open \"$output_log\"!! : $!\n";
   print $csv mk_head(), "\n";
   close $csv;
}

while($count < $freq){
   # ソケットの生成
   $ip = inet_aton($host) or die "Host[$host] not found!!\n";
   $sockaddr = pack_sockaddr_in($port, $ip);
   socket(SOCKET, PF_INET, SOCK_STREAM, 0) or die "Socket error!!\n";
   
   # ソケットの接続
   connect(SOCKET, $sockaddr) or die "Connect \"$host:$port\" error.\n";
   autoflush SOCKET (1);
   
   # HTTP要求を送信
   $now = strftime "%Y%m%d%H%M%S", localtime;
   ($params[0], $params[1]) = tr_dtm($now);
   $olog = "$output_org/$now.txt";
   if($http eq '1.1'){
      print SOCKET "GET $path HTTP/1.1\n";
      print SOCKET "Host: $host\n";
      print SOCKET "Connection: close\n\n";
   }else{
      print SOCKET "GET $path HTTP/1.0\n\n";
   }
   
   # HTTP応答を受信
   open($txt, "> $olog");
   while(<SOCKET>){
      print $txt $_;
      if(/Total Accesses:/){
         $params[2] = tr_dec(unpack("x16A*", $_));
      }elsif(/Total kBytes:/){
         $params[3] = tr_dec(unpack("x14A*", $_));
      }elsif(/CPULoad:/){
         $params[4] = tr_dec(unpack("x9A*", $_));
      }elsif(/Uptime:/){
         $params[5] = tr_dec(unpack("x8A*", $_));
      }elsif(/ReqPerSec:/){
         $params[6] = tr_dec(unpack("x11A*", $_));
      }elsif(/BytesPerSec:/){
         $params[7] = tr_dec(unpack("x13A*", $_));
      }elsif(/BytesPerReq:/){
         $params[8] = tr_dec(unpack("x13A*", $_));
      }elsif(/BusyWorkers:/){
         $params[9] = tr_dec(unpack("x13A*", $_));
      }elsif(/IdleWorkers:/){
         $params[10] = tr_dec(unpack("x13A*", $_));
      }elsif(/Scoreboard:/){
         $sc_key = unpack("x12A*", $_);
         (
            $params[11],
            $params[12],
            $params[13],
            $params[14],
            $params[15],
            $params[16],
            $params[17],
            $params[18],
            $params[19],
            $params[20],
            $params[21],
         ) = tr_score($sc_key);
      }
   }
   close $txt;
   chomp(@params);
   $line = join(",", @params);
   
   open($csv, ">> $output_log") or die "Cannot open \"$output_log\"!! : $!\n";
   print $csv $line, "\n";
   
   # 切断処理
   close SOCKET;
   close $csv;
   
   sleep($interval);
   $count++;
}

# 終了処理
exit(0);

sub tr_score{
   my $score = $_[0];
   my (@schar, @scount);
   my $key;
   
   @scount = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   @schar = split(/\B/, $score);
   while($key = shift(@schar)){
      if($key =~ /_/){
         $scount[0]++;
      }elsif($key =~ /S/){
         $scount[1]++;
      }elsif($key =~ /R/){
         $scount[2]++;
      }elsif($key =~ /W/){
         $scount[3]++;
      }elsif($key =~ /K/){
         $scount[4]++;
      }elsif($key =~ /D/){
         $scount[5]++;
      }elsif($key =~ /C/){
         $scount[6]++;
      }elsif($key =~ /L/){
         $scount[7]++;
      }elsif($key =~ /G/){
         $scount[8]++;
      }elsif($key =~ /I/){
         $scount[9]++;
      }elsif($key =~ /\./){
         $scount[10]++;
      }
   }
   return(@scount);
}

sub tr_dec{
   my $tmpline = $_[0];
   
   if($tmpline =~ /^\./){
      $tmpline = "0$tmpline";
   }
   return($tmpline);
}

sub mk_head{
   my @tmplist = (
      "Date",
      "Time",
      "Total Accesses",
      "Total kBytes",
      "CPULoad",
      "Uptime",
      "ReqPerSec",
      "BytesPerSec",
      "BytesPerReq",
      "BusyWorkers",
      "IdleWorkers",
      "Score[Waiting for Connection]",
      "Score[Starting up]",
      "Score[Reading Request]",
      "Score[Sending Reply]",
      "Score[Keepalive(read)]",
      "Score[DNS Lookup]",
      "Score[Closing connection]",
      "Score[Logging]",
      "Score[Gracefully finishing]",
      "Score[Idle cleanup of worker]",
      "Score[Open slot with no current process]",
   );
   my $tmpline = join(",", @tmplist);
   return($tmpline);
}

sub chk_dir{
   my @dirlist = @_;
   
   foreach $_(@dirlist){
      if(! -d $_){
         mkdir($_, 0664) or die "Cannnot create \"$_\" directory!! : $!\n";
      }
   }
   return(1);
}

sub tr_dtm{
   my $tmpline = $_[0];
   my @tmpdtm = ($tmpline =~ m/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/);
   
   return("$tmpdtm[0]/$tmpdtm[1]/$tmpdtm[2]", "$tmpdtm[3]:$tmpdtm[4]:$tmpdtm[5]");
}
