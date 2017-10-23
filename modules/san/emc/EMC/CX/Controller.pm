# $Id: Controller.pm,v 1.1 2007/02/05 00:26:11 gonter Exp $

use strict;

package EMC::CX::Controller;

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

sub get
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

1;

__END__

=head1 NAME

  EMC/CX/Controller.pm   -- Generic EMC Module for CX series storage processors (controllers)

=head1 SYNOPSIS

  use EMC::CX::Controller;

=head1 DESCRIPTION

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

  Gerhard Gonter <ggonter@cpan.org>

