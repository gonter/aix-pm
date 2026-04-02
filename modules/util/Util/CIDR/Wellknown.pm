#!/usr/bin/perl

use strict;

use Net::CIDR;

package Util::CIDR::Wellknown;

sub new
{
  my $class= shift;
  my $self= { Wellknown => {}, _seen => {} };
  bless $self, $class;
  $self->set(@_);
  $self;
}

sub set
{
  my $self= shift;
  my %pars= @_;
  foreach my $par (keys %pars) { $self->{$par}= $pars{$par} }
  $self;
}

sub cidr_info
{
  my $self= shift;
  my $ip= shift;

  return $self->{_seen}->{$ip} if (exists ($self->{_seen}->{$ip}));

  my $res;
  foreach my $who (keys %{$self->{Wellknown}})
  {
    my $x= $self->{Wellknown}->{$who};
    # print __LINE__, " ip=[$ip] x: ", main::Dumper($x);
    my $rc= Net::CIDR::cidrlookup($ip, @{$x->{cidr}});
    # print __LINE__, " rc=[$rc]\n";
    if ($rc == 1)
    {
      return $self->{_seen}->{$ip}= $x;
    }
  }

  return undef;
}

1;
