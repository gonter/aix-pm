#!/usr/bin/perl
# $Id: physicaldrive.pm,v 1.1 2010/10/21 11:02:16 gonter Exp $

use strict;
use Data::Dumper;

package HP::ACU::physicaldrive;

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
  my $port= shift;
  my $id= shift;

  unless (exists ($obj->{'port'}->{$port}->{$id}))
  {
    $obj->{'port'}->{$port}->{$id}= new HP::ACU::physicaldrive;
  }

  $obj->{'port'}->{$port}->{$id};
}

1;
