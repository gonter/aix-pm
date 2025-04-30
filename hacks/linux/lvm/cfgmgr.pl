#!/usr/bin/perl
# $Id: cfgmgr.pl,v 1.2 2016/05/25 12:37:14 gonter Exp $

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;

open (MSG, '/var/log/messages')    # RHEL, CentOS
  or open (MSG, '/var/log/syslog') # Ubuntu
  or open (MSG, '|-', 'journalctl -ex') # Debian
  or die "can't read messages";     # TODO: or try something else?

seek (MSG, 0, 2);

my $config= new Linux::cfgmgr ('messages' => *MSG);

$config->get_scsi_host ();
print "config: ", Dumper ($config);
$config->scan_scsi_host ();

package Linux::cfgmgr;

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj= {};
  bless $obj, $class;

  foreach my $par (keys %par)
  {
    $obj->{$par}= $par{$par};
  }

  $obj;
}

sub show_messages
{
  my $cfg= shift;

  local *M= $cfg->{'messages'};
  while (<M>)
  {
    print $_;
  }
}

sub scan_scsi_host
{
  my $cfg= shift;

  my $c_scsi_host= $cfg->{'scsi_host'};
  foreach my $scsi_host (sort keys %$c_scsi_host)
  {
    my $dev= $c_scsi_host->{$scsi_host};
# print "dev: ", main::Dumper ($dev);

    my $cmd= 'echo - - - >' . $dev->{'path'} . '/scan';
    system ($cmd);

    print ">>> [$cmd]\n";
    sleep (3);
    print "--- 8< ---\n";
    $cfg->show_messages ();
    print "--- >8 ---\n";
  }
}

sub get_scsi_host
{
  my $cfg= shift;

  my $sys_path= '/sys/class/scsi_host';

  opendir (D, $sys_path) or die;
  while (my $e= readdir (D))
  {
    next if ($e eq '.' || $e eq '..');
    if ($e =~ /^host\d+/)
    {
      $cfg->{'scsi_host'}->{$e}= { 'dev' => $e, 'path' => join ('/', $sys_path, $e) };
    }
  }
  closedir (D);
}

