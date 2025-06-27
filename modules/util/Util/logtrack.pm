#!/usr/bin/perl

package Util::logtrack;

use strict;

my $running= 1;

sub new
{
  my $class= shift;
  my $self=
  {
    seek_end => 0,
    follow => 0,
    track => 0,
    sleep_time => 1,
  };
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

sub process
{
  my $self= shift;
  my $fnm= shift;

  my @stat= stat($fnm) or die;
  my ($sleep_time, $seek_end, $track, $context, $cb_process, $cb_open, $cb_idle)=
      map { $self->{$_} } qw(sleep_time seek_end track context cb_process cb_open cb_idle);

  my $ref_running= (exists ($self->{ref_running})) ? $self->{ref_running} : \$running;

  # print __LINE__, " self: ", main::Dumper($self); exit;
REOPEN:
  open (FI, '<:utf8', $fnm) or die;
  my $inode= $stat[1];

  if ($seek_end)
  {
    # print __LINE__, " seeking end\n";
    seek(FI, 2, 0);
    while (<FI>) {};
    $seek_end= 0;
  }

  my $pos;
  if (defined ($cb_open))
  {
    $pos= tell(FI);
    &{$cb_open}($context, $fnm, $inode, $pos);
  }

  LINE: while ($$ref_running)
  {
    my $l= <FI>;

    unless (defined ($l))
    {
      if ($track)
      {
        @stat= stat($fnm);
	if ($stat[1] != $inode) # log rotation
	{
	  close (FI);
          goto REOPEN
	}
      }

      # do other idle tasks
      &{$cb_idle}($context) if (defined ($cb_idle));
      sleep($sleep_time);
      next LINE;
    }
    $pos= tell(FI);

    # do other log processing tasks
    if (defined ($cb_process))
    {
      &{$cb_process}($context, $l);
    }
    else
    {
      print __LINE__, " l=[$l]\n";
    }
  }

  return ($inode, $pos);
}

1;

