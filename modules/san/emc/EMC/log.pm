#
# $Id: log.pm,v 1.5 2010/02/17 15:46:35 gonter Exp $
#

package EMC::log;

use strict;

sub new
{
  my $class= shift;
  my $addr= shift;
  my $debug= shift;

  my $obj=
  {
    'addr' => $addr,
    'll' => undef,
    'debug' => $debug,
  };

  bless $obj, $class;
}

sub get_events
{
  my $obj= shift;

  my ($addr, $ll, $debug)= map { $obj->{$_} } qw(addr ll debug);

  # my $cmd= "/usr/bin/navicli -h $addr getlog -15";
  my $cmd= "/usr/bin/naviseccli -h $addr getlog -15";
  print scalar localtime (time ()), " EMC::log::get_events >>> $cmd\n" if ($debug);
  my @lines= `$cmd`;
  my @xlines= ();
  chop (@lines);
  @lines= reverse (@lines);
  my $l;
  foreach $l (@lines)
  {
    next unless ($l);
    $l=~ s/\r//g; # sometimes log lines contain CR chars

    # print ">>>> $l\n";
    last if ($ll eq $l);
    # print ">>>>> $l\n";

    push (@xlines, $l);
  }
  close (FI);

  if (@xlines)
  {
    @xlines= reverse (@xlines);
    $obj->{'ll'}= $xlines[$#xlines];
  }

  @xlines;
}

1;

