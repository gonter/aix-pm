#!/usr/bin/perl
# $Id: showvpd.pl,v 1.6 2012/04/22 20:04:12 gonter Exp $

=pod

=head1 NAME

showvpd.pl  --  show AIX VPD Data (from lscfg)

=cut

use strict;

use AIX::VPD::lscfg;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $debug_flag= 0;
my $show_devices= 0;
my $show_fcs= 0;
my $dev_list= 0;

my @JOBS;
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-h') { &usage; exit (0); }
    elsif ($arg eq '-d') { $debug_flag= 1; }
    elsif ($arg eq '-devs') { $show_devices= 1; }
    elsif ($arg eq '-fcs') { $show_fcs= 1; }
    elsif ($arg eq '-l') { $dev_list= 1; }
    elsif ($arg eq '--') { push (@JOBS, @ARGV); @ARGV= (); }
    else { &usage; }
    next;
  }

  push (@JOBS, $arg);
}

if (@JOBS)
{
  if ($dev_list)
  {
    &main_function (undef, @JOBS);
  }
  else
  {
    while (defined ($arg= shift (@JOBS)))
    {
      &main_function ($arg);
    }
  }
}
else
{
  &main_function ();
}

exit (0);

sub usage
{
  print <<EOX;
usage: $0 [-opts] pars

options:
-h  ... help
-x  ... set x flag
--  ... remaining args are parameters
EOX
}

# ----------------------------------------------------------------------------
sub main_function
{
  my $fnm= shift;
  my @devices= @_;
  ## print "main_function: $fnm\n";

  my $cfg= new AIX::VPD::lscfg;

  if ($fnm)
  {
    $cfg->read_lscfg ($fnm);
  }
  elsif (@devices)
  {
    foreach my $device (@devices)
    {
      $cfg->read_lscfg (undef, $device);
    }
  }
  else
  {
    $cfg->read_lscfg (); # read all device info from lscfg output
  }

  if ($debug_flag)
  {
    print 'cfg: ', Dumper ($cfg), "\n";
  }

  printf ("%-32s %s %s %s\n", $fnm, $cfg->get (qw(machine_type serial_number firmware)));

  if ($show_devices)
  {
    my %devs= $cfg->devices ();
    print 'Devices: ', join (' ', sort keys %devs), "\n";
  }

  if ($show_fcs)
  {
    my ($fcs_list)= $cfg->get ('fcs');
    my @fcs= sort @$fcs_list;

    print 'fcs: ', join (' ', @fcs), "\n";

    foreach my $fcs (@fcs)
    {
      my ($d1, $d2)= $cfg->device ($fcs);
      # print 'fcs_d1: ', Dumper ($d1), "\n";
      my $wwnn= $d1->WWNN ();
      my $wwpn= $d1->WWPN ();

      print join (' ', $fcs, $wwnn, $wwpn), "\n";
      # print "d1=$d1\n";
      # print "d2=$d2\n";
    }
  }

}

=cut

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over

