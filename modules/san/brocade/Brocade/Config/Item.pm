# $Id: Item.pm,v 1.4 2011/03/18 13:04:02 gonter Exp $

use strict;

package Brocade::Config::Item;

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->set (@_);

  $obj;
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

=pod

=head2 $po->get_port_specifier ()

Return the proper port specifier, e.g. for director blades something
like 9/3 or just 3 for "simple" switches.

=cut

sub get_port_specifier
{
  my $obj= shift;

  return (exists ($obj->{'Slot'})) ? join ('/', $obj->{'Slot'}, $obj->{'Port'}) : $obj->{'Port'};
}
1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR
   
Gerhard Gonter E<lt>ggonter@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2006..2010 by Gerhard Gonter
  
This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
    
=over

