# $Id: Tools.pm,v 1.2 2009/11/26 07:21:20 gonter Exp $

=pod

=head1 NAME

SAN::Tools

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;

package SAN::Tools;

use vars qw(@EXPORT_OK @ISA);
require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(hs2hp);

=cut

=head2 hs2hp ($wwn)

convert WWN from digit-only format to colon-separated digit-pairs

=cut

sub hs2hp
{
  my $s= shift;

  $s=~ s/^[Ww]//; # IBM notation?
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

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

