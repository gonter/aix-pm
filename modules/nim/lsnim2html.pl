#!/usr/bin/perl
#
# generate an overview for the configuration of a NIM environment
#
# $Id: lsnim2html.pl,v 1.7 2008/10/06 15:23:00 gonter Exp $
#

=pod

=head1 NAME

lsnim2html.pl

=head1 SYNOPSIS

lsnim2html.pl [cfg_name [lsnim_file]]

=head2 Parameters

=head3 cfg_name

name of the configuration environment, defaults to the current hostname

=head3 lsnim_file

if specified, read output of lsnim -l from that file, otherwise
read from lsnim -l directly.

=cut

use strict;

## use lib '/root/work/perl';   # TODO: this should be handled differently

use AIX::NIM::Config;
use AIX::NIM::Dashboard;
use Data::Dumper;
$Data::Dumper::Indent= 1;

# MAIN
my ($OS, $hostname)= split (' ', `uname -a`);
($hostname)= split (/\./, $hostname); # if hostname has a domain ...

my $NIM_POLICY_FILE= '/etc/nimpolicy';
my $FIX_POLICY_FILE= '/etc/fixpolicy';
my $client_inventories;
my $wanted_list;

my $dump_dashboard= 0;

my $FS= ';';

my @PARS= ();
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-i') { $client_inventories= shift (@ARGV); }
    elsif ($arg eq '-w') { $wanted_list= shift (@ARGV); }
    elsif ($arg eq '-DD') { $dump_dashboard= 1; }
    else
    {
      &usage;
      exit (0);
    }
    next;
  }
  push (@PARS, $arg);
}

my $cfg_name= shift (@PARS) || $hostname;
my $lsnim_input= shift (@PARS);

my $obj= new AIX::NIM::Config;
$obj->get_config ();

local *FO;
my $FO_name= "nim-config-$cfg_name.html";
open (FO, ">$FO_name") || die;
print "saving config to $FO_name\n";
$obj->print_html (*FO, $cfg_name);
close (FO);

my $nim_policy= new AIX::NIM::Config;
$nim_policy->get_config ($NIM_POLICY_FILE);
my $fix_policy= new AIX::NIM::Config;
$fix_policy->get_config ($FIX_POLICY_FILE);

# &save_host_list ($obj, 'nim-hosts.csv');
# &save_net_list ($obj, 'nim-nets.csv');

my $dashboard= new AIX::NIM::Dashboard ('debug' => 0);

$dashboard->map_hosts ($obj);
$dashboard->map_nim_policy ($nim_policy);

if ($client_inventories)
{
  $dashboard->map_client_inventories ($client_inventories);
}

if ($wanted_list)
{
  $dashboard->map_wanted_list ($wanted_list);
}

$dashboard->print_dashboard ('nim-dashboard.html', $FO_name);

if ($dump_dashboard && open (DD, '>@DEBUG.dashboard'))
{
  print DD "dasbhoard: ", Dumper ($dashboard), "\n";
  close (DD);
}

exit (0);

sub save_host_list
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or return undef;

  my $standalone= $obj->select_objects ('class' => 'machines', 'type' => 'standalone');
  return undef unless (defined ($standalone));

  if (0)
  {
    open (DEBUG, '>' . '@DEBUG.hosts');
    print DEBUG 'standalone: ', Dumper ($standalone), "\n";
    close (DEBUG);
  }

  print FO join ($FS, qw(nim_name net_name host_name comments)), "\n";

  foreach my $ho (@$standalone)
  {
    my $nim_name= $ho->av ('_name_');
    my $comments= $ho->av ('comments');
    $comments=~ s/$FS//g; # TODO: CSV processing needs to be improved
    my ($net_name, $host_name)= $ho->get_hostname ();
    print FO join ($FS, $nim_name, $net_name, $host_name, $comments), "\n";
  }
  close (FO);
  1;
}

sub save_net_list
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or return undef;

  my $nets= $obj->select_objects ('class' => 'networks'); # , 'type' => 'ent');
  return undef unless (defined ($nets));

  if (0)
  {
    open (DEBUG, '>' . '@DEBUG.nets');
    print DEBUG 'nets: ', Dumper ($nets), "\n";
    close (DEBUG);
  }

  print FO join ($FS, qw(nim_name net_addr snm routing1 comments)), "\n";

  foreach my $no (@$nets)
  {
    my ($nim_name, $net_addr, $snm, $routing1, $comments)=
             map { $no->av ($_); }
             qw(_name_ net_addr snm routing1 comments);
    $comments=~ s/$FS//g; # TODO: CSV processing needs to be improved

    print FO join ($FS, $nim_name, $net_addr, $snm, $routing1, $comments), "\n";
  }
  close (FO);
  1;
}

=cut

=head1= TODO

+ nim_script refers to a directory with scripts for hosts?

=head1 AUTHOR

Gerhard gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforg.net/

=over

