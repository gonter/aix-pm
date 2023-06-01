#!/usr/bin/perl

=head1 NAME

  Net::fanout

=head1 DESCRIPTION

Connect to a fanout pub/sub server to receive and send messages

=head1 SYNOPSIS

  my $fanout= Net::fanout->new( { PeerHost => 'ppt.example.org' } );
  $fanout->subscribe('mychannel');
  $fanout->announce('mychannel', 'test message');

=head1 STANDALONE MODE

Start fanout, subscribe to three channels and monitor these:

  perl -MNet::fanout -e 'Net::fanout::main()' -- --PeerHost=fanout.example.org --PeerPort=1986 channel1 channel2 channel3

=cut

use strict;

package Net::fanout;

use IO::Socket::INET;
use IO::Select;
use FileHandle;

my @config_pars= qw(PeerHost PeerAddr PeerPort Blocking Proto);
my $MAX_RETRIES= 100;

# debugging
my $show_dots= 0;
my $dots= 0;

__PACKAGE__->main() unless caller();

sub new
{
  my $class= shift;

  my $self=
  {
    PeerPort => 1986,
    Blocking => 0,
    Proto => 'tcp',
    _connected => 0,
    _subscribed => {},
    _backlog => [], # queued messages
  };

  bless ($self, $class);
  $self->configure(@_);

  $self;
}

sub configure
{
  my $self= shift;

  my %par= (ref($_[0]) eq '') ? @_ : %{$_[0]};
  my $connect= 0;
  foreach my $par (keys %par)
  {
    $self->{$par}= $par{$par};
    $connect= 1 if ($par eq 'PeerHost' || $par eq 'PeerAddr');
  }

  $self->connect() if ($connect);

  $self;
}

sub connect
{
  my $self= shift;

  my @par= ();
  foreach my $par (@config_pars)
  {
    push (@par, $par => $self->{$par}) if (exists($self->{$par}) && defined ($self->{$par}));
  }

  $self->{_socket}= my $socket= new IO::Socket::INET (@par);

  if (defined ($socket))
  {
    $socket->autoflush(1);
    $self->{_connected}= 1;
  }

  $socket;
}

sub connected
{
  my $self= shift;

  $self->{_connected};
}

sub subscribe
{
  my $self= shift;
  my $channel= shift;

  # print __LINE__, " subscribe channel=[$channel]\n";
  $self->send("subscribe $channel\n");
  $self->{_subscribed}->{$channel}= time();
}

sub unsubscribe
{
  my $self= shift;
  my $channel= shift;

  # print __LINE__, " unsubscribe channel=[$channel]\n";
  $self->send("unsubscribe $channel\n");
  delete ($self->{_subscribed}->{$channel});
}

sub subscribed
{
  my $self= shift;

  my @channels= keys %{$self->{_subscribed}};
  (wantarray) ? @channels : \@channels;
}

sub receive
{
  my $self= shift;

  my $line;
  if (@{$self->{_backlog}})
  {
    $line= shift(@{$self->{_backlog}});
  }
  else
  {
    my $data;
    my $rc= $self->{_socket}->recv($data, 4096);
    print __LINE__, " rc=[$rc]\n" if ($show_dots);
    if (defined ($data) && $data ne '')
    {
      my @data= split("\n", $data);
      $line= shift(@data);
      push (@{$self->{_backlog}}, @data) if (@data);
    }
  }

  # print __LINE__, " received line=[$line]\n";
  my ($channel, $msg)= split('!', $line, 2);

  # debugging only:
  if ($channel eq '')
  {
    if ($show_dots)
    {
      autoflush STDOUT 1;
      print '.';
      if ($dots++ >= 80) { print "\n"; $dots= 0; }
    }
  }
  else
  {
    if ($dots) { print "\n"; $dots= 0; }
  }
  ($channel, $msg);
}

sub announce
{
  my $self= shift;
  my $channel= shift;
  my @messages= shift;

  my $count= 0;
  foreach my $msg (@messages)
  {
    $self->send("announce $channel $msg\n");
    $count++;
  }

  $count;
}

sub send
{
  my $self= shift;
  my $msg= shift;

  my $s= $self->{_socket};
  $s= $self->connect() unless (defined ($s));

  my $retries= $MAX_RETRIES;
  RETRY: while ($retries--)
  {
    eval { $s->send($msg) };
    if ($@)
    {
      if ($dots) { print "\n"; $dots= 0; }
      sleep(0.05);
      next RETRY;
    }
    last;
  }
  die ("can not send to " . join(' ', map { $_ => $self->{$_} } @config_pars) . ' ' . $@) unless ($retries > 0);
  # print "sent [$msg]... $retries retries left\n";
  $retries;
}

sub main
{
  my $PeerHost= undef;
  my $PeerPort= 1986;

  my @channels= ();
  while (my $arg= shift(@ARGV))
  {
    if ($arg =~ /^--(.+)/)
    {
      my ($opt, $val)= split('=', $1, 2);
         if ($opt eq 'PeerHost') { $PeerHost= $val || shift(@ARGV); }
      elsif ($opt eq 'PeerPort') { $PeerPort= $val || shift(@ARGV); }
      # TODO: else report problem
    }
    else
    {
      push (@channels, $arg);
    }
  }

  die "need --PeerHost=hostname" unless (defined ($PeerHost));

  my $fanout= Net::fanout->new( { PeerHost => $PeerHost, PeerPort => $PeerPort } );
  foreach my $channel (@channels)
  {
    $fanout->subscribe($channel);
  }

  my $stdin= IO::Select->new();
  $stdin->add(\*STDIN);

  while (1)
  {
    my ($channel, $msg)= $fanout->receive();
    if (defined ($channel))
    {
      print join(' ', scalar localtime(time()), $channel, $msg), "\n";
    }

    if ($stdin->can_read(0.2))
    {
      my $l= <STDIN>; chop($l);
      my ($cmd, $channel, $msg)= split(' ', $l, 3);
         if ($cmd eq 'subscribe') { $fanout->subscribe($channel); }
      elsif ($cmd eq 'unsubscribe') { $fanout->unsubscribe($channel); }
      elsif ($cmd eq 'announce') { $fanout->announce($channel, $msg); }
      elsif ($cmd eq 'ping') { $fanout->send("ping\n"); }
      elsif ($cmd eq 'info') { $fanout->send("info\n"); }
      elsif ($cmd eq '') { } # NOP
      elsif ($cmd eq 'help')
      {
        print <<EOX;
subscribe channel
unsubscribe channel
announce channel message
ping
info
EOX
      }
      else { print "unknown command '$cmd'\n"; }
    }
  }

}

1;

__END__

=head1 TODO

 * Lost connections to the fanout server are not detected, so at some
   point, the application might crash, e.g. when something is sent to
   the fanout server.

