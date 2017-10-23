# $Id: FAS.pm,v 1.1 2012/01/31 10:30:45 gonter Exp $

=pod

=head1 NAME

  NetApp::FAS   -- Generic NetApp Module for FAS series SANs

=head1 SYNOPSIS

  use NetApp::FAS;
  my $CX= new NetApp::FAS (%parameters);

=head1 DESCRIPTION

=cut

use strict;

package NetApp::FAS;

use NetApp::FAS::Controller;

my %SUPPORTED_MODEL= map { $_ => 1 } qw(FAS6240);

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

=head2 $x= is_supported NetApp::FAS ('FAS6240');

returns true if given model name is suppored by this module.

=cut

sub is_supported
{
  my $p1= shift;
  my $p2= shift;

  ## print "p1='$p1' ref(p1)='", ref($p1), "'\n";
  ## print "p2='$p2'\n";

  my $model;

     if (ref($p1) eq '' && $p1 eq 'NetApp::FAS' && $p2) { $model= $p2; } # NetApp::FAS::is_suppred ($model);
  elsif (ref($p1) eq '' && $p1) { $model= $p1; } # is_supported NetApp::FAS ($model);
  elsif (ref($p1) =~ /NetApp::FAS/) { $model= $p2; } # $obj->is_suppored ($model);
  else { print "unknown request!\n"; }

  ## print "model='$model'\n";

  return $SUPPORTED_MODEL{$model};
}

sub new_controller
{
  my $obj= shift;
  my $name= shift;

print join (' ', __FILE__, __LINE__, "new_controller: name=[$name]"), "\n";
  my $ctrl= new NetApp::FAS::Controller ('name' => $name, @_);
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

