#!/usr/bin/perl -w
my $ipaddr = $ENV{"REMOTE_ADDR"};

print "Content-type: text/html\n\n";
print $ipaddr;

exit(0);