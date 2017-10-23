#!/usr/bin/perl
# $Id: Package.pm,v 1.3 2008/10/08 13:22:46 gonter Exp $

# NOTE:
# packages "AIX::Software::Package" and "AIX::Software::Fileset"
# are used to generate templates for mkinstallp

package AIX::Software::Package;

use strict;

my $verbose= 1;
my $doit= 1;

my %DEFAULTS=
(
  'Package Name' => 'dummy.package',
  'Package VRMF' => '1.0.0.0',
  'Update' => 'N',
);

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->defaults ();
  $obj->set (@_);

  $obj;
}

sub defaults
{
  my $obj= shift;

  foreach my $kw (keys %DEFAULTS)
  {
    $obj->{$kw}= $DEFAULTS{$kw} unless (exists ($obj->{$kw}));
  }
}

sub set
{
  my $obj= shift;
  my %par= @_;

  my %res;
  foreach my $par (keys %par)
  {
    $res{$par}= $obj->{$par};
    $obj->{$par}= $par{$par};

    if ($par eq 'verbose') { $verbose= $par{'verbose'}; }
    elsif ($par eq 'doit') { $doit= $par{'doit'}; }
  }

  (wantarray) ? %res : \%res;
}

sub get_array
{ 
  my $obj= shift;
  my @par= @_;

  my @res;
  foreach my $par (@par)
  { 
    push (@res, $obj->{$par});
  }

  (wantarray) ? @res : \@res;
}

sub get_hash
{ 
  my $obj= shift;
  my @par= @_;

  my %res;
  foreach my $par (@par)
  { 
    $res{$par}= $obj->{$par};
  }

  (wantarray) ? %res : \%res;
}

*get= *get_array;

sub mkinstallp
{
  my $desc= shift;

  my ($template, $stage)= map { $desc->{$_} } qw(template stage);
  my ($name, $vrmf)= map { $desc->{$_} } ('Package Name', 'Package VRMF');

  my $bff_file= "$stage/tmp/$name.$vrmf.bff";

  &do ("mkinstallp -T $template -d $stage 2>&1");
  &do ("cp $bff_file pkg/rs_aix53");
}

sub do
{
  foreach my $c (@_)
  {
    print ">>> $c\n" if ($verbose);
    system ($c) if ($doit);
  }
}

1;

