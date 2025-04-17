#!/usr/bin/perl

use strict;

package Util::CIDR;

use Net::CIDR;

__PACKAGE__->main() unless caller();

sub new
{
  my $class= shift;

  my $self= { _cidr => {}, _ips => {} };
  bless ($self, $class);
  $self->set(@_);

  $self;
}

sub set
{
  my $self= shift;
  my %pars= @_;
  foreach my $par (keys %pars)
  {
    $self->{$par}= $pars{$par};
  }
  $self;
}

sub add_cidr
{
  my $self= shift;
  my $ip_block= shift;
  my $comment= shift;

  my $v= Net::CIDR::cidrvalidate($ip_block);
  return undef unless (defined ($v) && $ip_block =~ m#/#);

  my $cidr= $self->{_cidr};

  my $b;
  unless (defined ($b= $cidr->{$ip_block}))
  {
    $b= $cidr->{$ip_block}= { ip_block => $ip_block };
  }

  if ($comment)
  {
    # print __LINE__, " comment=[$comment] b: ", main::Dumper($b);
    my $c;
    unless (defined ($c= $b->{comments})) { $c= $b->{comments}= [] }
    push (@$c => $comment);
  }

  $b;
}

sub read_cidr_list
{
  my $self= shift;
  my $fnm= shift;

  unless (open (FI, '<:utf8', $fnm))
  {
    print __LINE__, " can't read CIDR list from fnm=[$fnm]\n";
    return 0;
  }

  my $cnt= 0;
  L: while (defined (my $l= <FI>))
  {
    chop($l);

    next L if ($l eq '' || $l =~ m/^#/);

    my ($ip_block, $comment)= split(' ', $l, 2);
    $self->add_cidr($ip_block, $comment);

    $cnt++;
  }
  close(FI);

  $cnt;
}

=head2 lookup

lookup IP address in cidr list and return structure pointing to the IP block and counter

=cut

sub lookup
{
  my $self= shift;
  my $ip= shift;

  if (exists ($self->{_ips}->{$ip}))
  {
    my $x= $self->{_ips}->{$ip};
    $x->{count}++;
    return $x;
  }

  # not yet looked up...
  my $x= $self->{_ips}->{$ip}= { count => 1 };
  my $c= $self->{_cidr};
  L: foreach my $cidr (keys %$c)
  {
    if (Net::CIDR::cidrlookup($ip, $cidr))
    {
      my $b= $c->{$cidr};
      $x->{ip_block}= $b;
      last;
    }
  }

  $x;
}

sub main
{
  print join (' ', __FILE__, __LINE__, 'main: caller=['. caller(). ']'), "\n";
}

