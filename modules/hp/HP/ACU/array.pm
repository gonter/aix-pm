#!/usr/bin/perl
# $Id: array.pm,v 1.1 2010/10/21 11:02:16 gonter Exp $

use strict;
use Data::Dumper;

use HP::ACU::item;

package HP::ACU::array;

sub new
{
  my $class= shift;
  my $obj= {};
  bless $obj, $class;
  $obj;
}

sub physicaldrive
{
  my $obj= shift;
  my $pd_id= shift;

  unless (exists ($obj->{'pd_id'}->{$pd_id}))
  {
    $obj->{'pd_id'}->{$pd_id}= new HP::ACU::item;
  }

  $obj->{'pd_id'}->{$pd_id};
}

sub logicaldrive
{
  my $obj= shift;
  my $ld_id= shift;

  unless (exists ($obj->{'ld_id'}->{$ld_id}))
  {
    $obj->{'ld_id'}->{$ld_id}= new HP::ACU::item;
  }

  $obj->{'ld_id'}->{$ld_id};
}

1;
