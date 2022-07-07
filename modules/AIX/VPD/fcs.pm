# $Id: fcs.pm,v 1.3 2008/08/30 14:16:49 gonter Exp $

=pod

=head1 NAME

  AIX::VPD::fcs   --  fibre channel devices from AIX device data

=cut

use strict;

package AIX::VPD::fcs;

my $VERSION= '0.01';

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;
  $obj;
}

sub WWNN
{
  my $obj= shift;
  my $wwnn= $obj->{'Device Specific.(Z8)'};
  return &hs2hp ($wwnn);
}

sub WWPN
{
  my $obj= shift;
  my $wwpn= $obj->{'Network Address'};
  return &hs2hp ($wwpn);
}

sub hs2hp
{
  my $s= shift;

  $s=~ tr/A-F/a-f/;
  my @s= split ('', $s);
  my @r;

  while (@s)
  {
    push (@r, shift (@s). shift (@s));
  }

  join (':', @r);
}

1;

=pod

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more inforation, see http://aix-pm.sourceforge.net/

=over

