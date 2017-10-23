#!/usr/bin/perl
# $Id: item.pm,v 1.1 2010/10/21 11:02:16 gonter Exp $

use strict;
use Data::Dumper;

package HP::ACU::item;

sub new
{
  my $class= shift;
  my $obj= {};
  bless $obj, $class;
  $obj;
}

1;
