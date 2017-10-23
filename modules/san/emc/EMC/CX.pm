# $Id: CX.pm,v 1.8 2012/01/31 10:29:13 gonter Exp $

=pod

=head1 NAME

  EMC::CX   -- Generic EMC Module for CX series SANs

=head1 SYNOPSIS

  use EMC::CX;
  my $CX= new EMC::CX (%parameters);

=head1 DESCRIPTION

=cut

use strict;

package EMC::CX;

use EMC::CX::Controller;

my %SUPPORTED_MODEL= map { $_ => 1 } qw(CX3-80 AX4-5 CX4-120 CX4-240);

sub new
{
  my $class= shift;

  my $obj=
  {
    'wwpn' => {},
    '_cache_' => {},
  };
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

  my @res;
  foreach my $par (@par)
  {
    push (@res, $obj->{$par});
  }

### print __LINE__, " get: res=", join (' ', @res), "\n";
  (wantarray) ? @res : \@res;
}

=pod

=head2 $x= is_supported EMC::CX ('CX3-80');

returns true if given model name is suppored by this module.

=cut

sub is_supported
{
  my $p1= shift;
  my $p2= shift;

  ## print "p1='$p1' ref(p1)='", ref($p1), "'\n";
  ## print "p2='$p2'\n";

  my $model;

     if (ref($p1) eq '' && $p1 eq 'EMC::CX' && $p2) { $model= $p2; } # EMC::CX::is_suppred ($model);
  elsif (ref($p1) eq '' && $p1) { $model= $p1; } # is_supported EMC::CX ($model);
  elsif (ref($p1) =~ /EMC::CX/) { $model= $p2; } # $obj->is_suppored ($model);
  else { print "unknown request!\n"; }

  ## print "model='$model'\n";

  return $SUPPORTED_MODEL{$model};
}

sub new_controller
{
  my $obj= shift;
  my $name= shift;

  my $ctrl= new EMC::CX::Controller ('name' => $name, @_);
  $obj->{'Controller'}->{$name}= $ctrl;
}

sub find_wwpn
{
  my $obj= shift;
  my $wwpn= shift;

  return (exists ($obj->{'wwpn'}->{$wwpn})) ? $obj->{'wwpn'}->{$wwpn} : undef;
}

1;

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

See http://aix-pm.sourceforge.net/ for detail.

=over

