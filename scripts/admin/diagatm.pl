#!/usr/local/bin/perl
#
# atm interface diagnostics
#
# written:       2000-01-15
# latest update: 2000-01-22
#

use strict;
use lib '.';

my $ID= '$Id: diagatm.pl,v 1.1.1.1 2000/02/27 21:40:41 gonter Exp $';

use AIX::dev::atm;

my $adapter= 'atm0';
my $nw_device= 'at0';
my $sleep_time= 60;
my $loop_count= 1; # -1 loop forever
my $log= 1;

my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-loop') { $loop_count= shift (@ARGV); }
    elsif ($arg eq '-4e4') { $loop_count= -1; }
    else { &usage; exit (0); }
    next;
  }
}

my $obj= new AIX::dev::atm ($adapter, $nw_device);

my $av= $obj->attributes;
my @watch= qw(
  max_sml_bufs max_med_bufs max_lrg_bufs
  max_hug_bufs max_spec_bufs
);
my @syslog= qw(max_lrg_bufs);

$av->print_attr (@watch);
$av->log_watch (@syslog);
# &get_acceptable_range ($av);

if ($log)
{
  $log= 0 unless open (LOG, "|logger");
  print "*syslog*\n" if ($log);
  local $|= 1;
}

while ($loop_count)
{
  # my $stat= $obj->statistics;
  my @res= $obj->diag_mbuf ('verbose' => 1);
  print 'results: ', join (' ', @res), "\n";
  if ($log)
  {
    print LOG "$adapter/$nw_device: ", join (' ', @res), "\n";
  }
  sleep ($sleep_time);
  $loop_count-- if ($loop_count > 0);
}

exit (0);

sub usage
{
  print <<EOX;
usage: lsattr.pl [-opts]

Options:
-loop <n>     ... loop <n> times
-4e4          ... loop forever
$ID
EOX
}

