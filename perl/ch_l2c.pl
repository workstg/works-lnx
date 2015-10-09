#!/usr/bin/perl -w

my (@tmpline, @tmplist);
my ($numline, $tmpnum) = (0, 0);
my ($i, $j, $k, $l) = (0, 0, 0, 0);

while(<>){
   $tmpline[$i] = $_;
   $i++;
}

while($j <= $#tmpline){
   $tmplist[$j] = valcut($tmpline[$j]);
   $j++;
}

foreach $_(@tmplist){
   $tmpline = $#{$_};
   if($numline < $tmpline){
      $numline = $tmpline;
   }
}

while($k <= $numline){
   while($l <= $#tmplist){
      if(defined ${$tmplist[$l]}[$k]){
         print "${$tmplist[$l]}[$k]";
      }
      if($l != $#tmplist){
         print ",";
      }
      $l++;
   }
   print "\n";
   $l = 0;
   $k++
}

sub valcut{
   my @tgtval = split(/,/, $_[0]);
   chomp(@tgtval);
   return(\@tgtval);
}
