#!/usr/local/bin/perl

package AIX::fs::vg;

sub new
{
  my $class= shift;

  my $vg_name= shift;
  my $vg_id= shift;

  my $obj= { 'vg_name' => $vg_name };
  $obj->{'vg_id'}= $vg_id if ($vg_id);

  bless $obj;
}

1;
