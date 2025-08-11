#!/usr/bin/perl

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;
$Data::Dumper::Sortkeys= 1;

use lib '.';

use Util::LongJob;

srand (time () ^ $$);

my $max_jobs= 10;
my $max_jobs_total= 50;
my $cnt_jobs_total= 0;

my $lj= Util::LongJob->new();

my $running= 1;
my $allow_new_jobs= 1;

$SIG{INT}= sub { $allow_new_jobs= 0 };

while ($running)
{
  my $num_jobs= $lj->running_jobs();
  print __LINE__, " num_jobs=[$num_jobs] allow_new_jobs=[$allow_new_jobs] cnt_jobs_total=[$cnt_jobs_total]\n";

  if ($allow_new_jobs && $num_jobs < $max_jobs)
  {
    my $pid= start_job();
    print __LINE__, " started job number=[", $num_jobs+1, "], pid=[$pid]\n";
  }
  elsif ($num_jobs == 0 && !$allow_new_jobs)
  {
    $running= 0;
  }
  # else {} keep looping and wait for running jobs

  print __LINE__, " sleep(3) running=[$running]\n";
  sleep(3) if ($running);
}

my @reaped_jobs= $lj->reaped_jobs();
print __LINE__, " reaped_jobs: ", Dumper(\@reaped_jobs);

exit(0);

sub start_job
{
  my $sleep_time= int(rand(30)+30);
  print __LINE__, " sleep_time=[$sleep_time]\n";

  my $task=
  {
    command => 'sleep',
    argv => [$sleep_time],
    # cb_finished => \&finished, # TBD...
  };

  my $pid= $lj->start( $task );
  $allow_new_jobs= 0 if (++$cnt_jobs_total >= $max_jobs_total);
  print __LINE__, " start_job: pid=[$pid] sleep_time=[$sleep_time] cnt_jobs_total=[$cnt_jobs_total]\n";

  $pid;
}

sub finished
{
  my $task= shift;
}

