#!/usr/bin/perl
# $Id: ACU.pm,v 1.1 2010/10/21 11:02:16 gonter Exp $

use strict;
use Data::Dumper;
use HP::ACU::array;

package HP::ACU;

my $hpacucli= '/usr/sbin/hpacucli';

my %ignore= map { $_ => 1 } (
  q[FIRMWARE UPGRADE REQUIRED: A firmware update is recommended for this controller],
  q[                           to prevent rare potential data write errors on a],
  q[                           RAID 1 or RAID 1+0 volume in a scenario of],
  q[                           concurrent background surface analysis and I/O write],
  q[                           operations.  Please refer to Customer Advisory],
  q[                           c01587778 which can be found at hp.com.],
  q[Warning: Deleting an array can cause other array letters to become renamed.],
  q[         E.g. Deleting array A from arrays A,B,C will result in two remaining],
  q[         arrays A,B ... not B,C],
);

# print "ignore: ", Dumper (\%ignore), "\n";

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj= { 'ctrl_slot' => 0 };
  bless $obj, $class;
  $obj->reset ();

  foreach my $par (keys %par)
  {
    if ($par eq 'pd_watch')
    { # list of physical drives to watch
      my $v= $par{$par};
      my $p= $obj->{'pd_watch'};
      $p= $obj->{'pd_watch'}= {} unless (defined($p));

         if (ref($v) eq 'HASH')  { map { $obj->watch ($_, $v->{$_}); } keys %$v; }
      elsif (ref($v) eq 'ARRAY') { map { $obj->watch ($_); } @$v; }
    }
    else
    {
      $obj->{$par}= $par{$par};
    }
  }
  
  $obj;
}

sub reset
{
  my $obj= shift;

  map { $obj->{$_}= {}; } qw(array pd_id ld_id);
}

=pod

=head2 $acu->watch (name, [an => av]*);


=cut

sub watch
{
  my $obj= shift;
  my $pd_id= shift;
  my %par= @_;

  my $p= $obj->{'pd_watch'}->{$pd_id};
  unless (defined ($p))
  {
    $p= $obj->{'pd_watch'}->{$pd_id}= {};
  }

  $p->{'watched'}= 1;
  $p->{'pd_id'}= $pd_id;

  foreach my $par (keys %par)
  {
    $p->{$par}= $par{$par};
  }

  $p;
}

=pod

=head2 $acu->watched ([name]);

if name is specified, return watched disks data,
otherwise return sorted list of watched disks names.

=cut

sub watched
{
  my $obj= shift;
  my $name= shift;

  my $w= $obj->{'pd_watch'};

  unless (defined ($w))
  {
    $w= $obj->{'pd_watch'}= {};
  }

  if (defined ($name))
  {
    my $x= $w->{$name};
    unless (defined ($x))
    {
      $x= $w->{$name}= {};
    }
    return $x;
  }

  return sort keys %$w;
}

sub array
{
  my $obj= shift;
  my $name= shift;
  
  unless (exists ($obj->{'array'}->{$name}))
  {
    $obj->{'array'}->{$name}= new HP::ACU::array;
  }

  $obj->{'array'}->{$name};
}

sub ld_create
{
  my $obj= shift;
  my $drives= shift;

  my $ctrl= $obj->{'ctrl_slot'};

  $obj->get_cmd ("$hpacucli ctrl slot=$ctrl create type=ld drives=$drives");
}

sub ld_delete
{
  my $obj= shift;
  my $ld_id= shift;

  my $ctrl= $obj->{'ctrl_slot'};
  my $cmd= "$hpacucli ctrl slot=$ctrl ld $ld_id delete forced";

  $obj->get_cmd ($cmd);
}

sub get_config
{
  my $obj= shift;

  my $ctrl= $obj->{'ctrl_slot'};

  $obj->get_cmd ("$hpacucli ctrl slot=$ctrl pd all show");
  $obj->get_cmd ("$hpacucli ctrl slot=$ctrl ld all show");
  # $obj->get_cmd ("$hpacucli ctrl slot=$ctrl array all show");

  my @arrays= sort keys %{$obj->{'array'}};
  my $pd_watch= $obj->{'pd_watch'};

  foreach my $array (@arrays)
  {
    # XXX next if ($array eq 'A'); # system disks!

    # $obj->get_cmd ("$hpacucli ctrl slot=$ctrl array all show");
    print "array=[$array]\n";
    my $ua= $obj->{'array'}->{$array};
    my $uap= $ua->{'pd_id'};

    my $watched= 0;
    foreach my $ua_disk (keys %$uap)
    {
      next unless (exists ($pd_watch->{$ua_disk}));
      $obj->get_cmd ("$hpacucli ctrl slot=$ctrl pd $ua_disk show");
      $watched++;
    }

    if ($watched)
    {
      my $ldp= $ua->{'ld_id'};
      foreach my $ld_id (keys %$ldp)
      {
        $obj->get_cmd ("$hpacucli ctrl slot=$ctrl ld $ld_id show");
      }
    }
  }
}

sub get_cmd
{
  my $obj= shift;
  my $cmd= shift;

  print ">>> $cmd\n";

  open (CMD, $cmd . '|') or die;

  my $state= undef;
  my $array= undef;
  my $array_name= 'unknown';
  my $physicaldrive= undef;
  my $logicaldrive= undef;

  my $show_lines= ($obj->{'verbose'} >= 1) ? 1 : 0;

  while (<CMD>)
  {
    chop;

    next if ($_ eq '' || exists ($ignore{$_}));

    print "[$_]\n" if ($show_lines);

    if ($_ =~ q[Smart Array 6i in Slot (\d+) ])
    {
    }
    elsif ($_ eq q[   unassigned])
    {
      $state= 'array';
      $array= $obj->array ($array_name= 'unassigned');
    }
    elsif ($_ =~ m[^   array (\S+)])
    {
      $array_name= $1;
      $array= $obj->array ($array_name);

      $state= 'array';
    }
    elsif ($_ =~ m[^      physicaldrive ((\d+):(\d+))])
    {
      my ($pd_id, $port, $id)= ($1, $2, $3);
      $physicaldrive= $array->physicaldrive ($pd_id); 

      $state= 'physicaldrive';
      $obj->{'pd_id'}->{$pd_id}= $array_name;
    }
    elsif ($_ =~ m[^      logicaldrive (\d+) ])
    { # just a listing of logical drives
      my $ld_id= $1;
      $logicaldrive= $array->logicaldrive ($ld_id); 
      $state= undef;
      $obj->{'ld_id'}->{$ld_id}= $array_name;
    }
    elsif ($_ =~ m[^      Logical Drive: (\d+)])
    { # more details about a logical drive
      my $ld_id= $1;
      $logicaldrive= $array->logicaldrive ($ld_id); 
      $state= 'logicaldrive';
      $obj->{'ld_id'}->{$ld_id}= $array_name;
    }
    elsif ($_ =~ m[^         (.+):\s+(.+)])
    {
      my ($an, $av)= ($1, $2);

      if ($state eq 'physicaldrive')
      {
        $physicaldrive->{$an}= $av;
        # push (@{$physicaldrive->{'_'}}, $_);
      }
      elsif ($state eq 'logicaldrive')
      {
        $logicaldrive->{$an}= $av;
      }
      else
      {
        goto UNKNOWN;
      }
    }
    else
    {
UNKNOWN:
      print __LINE__, " >>> [$_]\n";
    }

  }
  close (CMD);
}

1;
__END__
