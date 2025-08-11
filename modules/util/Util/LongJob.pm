#!/usr/bin/perl

use strict;

package Util::LongJob;

use POSIX;

my @running_jobs= ();
my @reaped_jobs= ();

sub new
{
  my $class= shift;

  my $self=
  {
    # _jobs => [],
  };
  bless ($self, $class);
  $self->set(@_) if (@_);

  unless (exists ($self->{reaper}))
  {
    $SIG{CHLD}= $self->{reaper}= \&reaper;
  }

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

sub start
{
  my $self= shift;
  my $job= shift;

  my $pid= fork ();

  if ($pid == 0)
  { # child
    my @cmd= ($job->{command}, @{$job->{argv}});
    $SIG{INT}= 'IGNORE';
    print __LINE__, " LJ: child: command=[", join(' ', @cmd), "]\n";
    exec(@cmd);
  }
  elsif ($pid > 0)
  { # parent
    $job->{pid}= $pid;
    # push (@{$self->{_jobs}}, $job);
    push (@running_jobs, $job);
  }
  else
  { # errror
  }

  $pid;
}

sub running_jobs
{
  my $self= shift;
  # my @a= scalar @{$self->{_jobs}};

  (wantarray) ? @running_jobs : scalar @running_jobs;
}

sub reaped_jobs
{
  my $self= shift;
  # my @a= scalar @{$self->{_reaped_jobs or so...}};

  (wantarray) ? @reaped_jobs : scalar @reaped_jobs;
}

sub reaper
{
  P: while ((my $pid= waitpid(-1, WNOHANG)) > 0)
  {
    print __LINE__, " reaper: pid=[$pid]\n";
    J: for (my $i= 0; $i <= $#running_jobs; $i++)
    {
      if ($running_jobs[$i]->{pid} == $pid)
      {
        push (@reaped_jobs, splice(@running_jobs, $i, 1)); # remove job
        last J;
      }
    }
  }
  # SIG{CHLD}= &reaper; # is this necessary?
}

1;

