# $Id: Controller.pm,v 1.1 2012/01/31 10:30:45 gonter Exp $

use strict;

package NetApp::FAS::Controller;

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

  NetApp::FAS::Controller   -- Generic NetApp Module for FAS series storage processors (controllers)

=head1 SYNOPSIS

  use NetApp::FAS::Controller;

=head1 DESCRIPTION

=head1 BUGS

* same as EMC::CX::Controller, maybe this should be refactored...

=head1 REFERENCES

=head1 AUTHOR

  Gerhard Gonter <ggonter@cpan.org>

