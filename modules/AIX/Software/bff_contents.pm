# $Id: bff_contents.pm,v 1.2 2011/09/16 18:14:26 gonter Exp $

package AIX::Software::bff_contents;

use strict;

sub new
{
  my $cl= shift;
  my $bff=
  {
    'filesets' => [],
  };
  bless $bff, $cl;
  $bff;
}

1;
