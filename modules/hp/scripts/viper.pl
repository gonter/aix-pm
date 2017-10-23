#!/usr/bin/perl
# $Id: viper.pl,v 1.2 2010/10/21 12:09:11 gonter Exp $

use strict;
use lib 'perl';

use Data::Dumper;
use HP::ACU;

$Data::Dumper::Indent= 1;

my $ctrl_slot= 0;

my $cache= 1;
my $mode= undef;
my @PARS= ();
my @pd_watch= ();
my @pd_wiped= ();
my $verbose= 0;
my $watch= 0;

my @JOBS= ();

while (my $arg= shift (@ARGV))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '--dumpconf') { $cache= 1; }
    elsif ($arg eq '--useconf') { $cache= 2; }
    elsif ($arg eq '--pd_watch') { $mode= $arg; }
    elsif ($arg eq '--wiped') { $mode= $arg; }
    elsif ($arg eq '--verbose' || $arg eq '-v') { $verbose= 1; }
    elsif ($arg eq '--TL') { $mode= 'TL'; }
    elsif ($arg eq '--TJ') { $mode= 'TJ'; }
    else { &usage; exit (0); }
  }
  else
  {
       if ($mode eq '--pd_watch') { push (@pd_watch, $arg); }
    elsif ($mode eq '--wiped')    { push (@pd_wiped, $arg); }
    else                          { push (@JOBS, $arg); }
  }
}

if ($mode eq 'TL')
{
  foreach my $arg (@JOBS)
  {
    my ($prog, $errors, $unknown)= &examine_job_progress ($arg); # EJP
    print "$arg prog=$prog errors='$errors' unknown='$unknown'\n";
  }
  exit (0);
}

if ($mode eq 'TJ')
{
  print scalar localtime (), "\n";
  # my @res= ();
  foreach my $arg (@JOBS)
  {
    my $wi= {};
    my ($ji, $progress)= &examine_job_file ($wi, $arg); # EJF

    my $prog= $wi->{'prog'};
    my $start= $ji->{'start_e'};
    my $size= $ji->{'size'};
    my $now= time ();

    my $eta= 'unknown';
    if ($prog > 0.0)
    {
      $eta= ($prog < 1.0) ? (scalar localtime (($now-$start)/$prog + $start)) : 'finished';
    }

    my $l= join (' ', $arg, "eta=[$eta]", "size=$size",
                 map { $_.'='.$wi->{$_}; } qw(log_file progress prog errors unknown));
    print $l, "\n";

    # print 'wi=', Dumper ($wi), "\n";
    # print 'ji=', Dumper ($ji), "\n";
  }

  # foreach (@res) { print $_, "\n"; }
  exit (0);
}

my $SLEEP_TIME= (scalar @pd_watch) * 5;

my $acu= new HP::ACU ('ctrl_slot' => $ctrl_slot, 'pd_watch' => \@pd_watch, 'verbose' => $verbose);

my $conf_dump= "acu_${ctrl_slot}.dump";

if ($cache == 0 || $cache == 1)
{
  &read_config ($acu);
}
elsif ($cache == 2)
{
  ## do $conf_dump;
  ## $acu= $VAR1;
}

while (1)
{
  if (@pd_wiped)
  {
    &mark_wiped ($acu, @pd_wiped);
    @pd_wiped= ();
  }

  &create_arrays ($acu);

  # if unwiped ...
  my ($forked, $running, $finished)= &check_wipe_discs ($acu);
  print "$forked jobs forked\n";
  print "$running jobs already running\n";
  @pd_wiped= sort keys %$finished;
  print scalar (@pd_wiped), " jobs already finished: [", join (',', @pd_wiped), "]\n";

  unless ($watch)
  {
    # TODO: cleanup job files for finished jobs!
    if (@pd_wiped)
    {
      my $done_dir= "done/" . &ts ();
      mkdir $done_dir;
      foreach my $pd_wiped (@pd_wiped)
      {
        my $wi= $acu->{'pd_watch'}->{$pd_wiped};
        my ($job_file, $log_file)= map {$wi->{$_}; } qw(job_file log_file);
        print "wiped pd_id=[$pd_wiped] job_file='$job_file' log_file='$log_file'\n";
	system ("mv '$job_file' '$done_dir'");
	system ("mv '$log_file' '$done_dir'");
	# print "wi=", Dumper ($wi), "\n";
      }

      &mark_wiped ($acu, @pd_wiped);
    }
    last;
  }

  # TODO: sleep timer and/or waitpid for forked processes
  sleep (300);
}

exit (0);

sub check_wipe_discs
{
  my $acu= shift;

  my $fork_count= 0;
  my $job_count= 0;
  my %finished= ();

print "check_wipe_discs\n";
  my $pd_watch= $acu->{'pd_watch'};
  my @pd_watch= sort keys %$pd_watch;

  foreach my $pd_id (@pd_watch)
  {
    my $watch_info= $pd_watch->{$pd_id};
    next unless ($watch_info->{'watched'} == 1);

    my $array= $acu->{'array'}->{$acu->{'pd_id'}->{$pd_id}};
# print "pd_id='$pd_id' array='$array'\n";

    my $pd_p= $array->{'pd_id'}->{$pd_id};
    $watch_info->{'sernr'}= my $sernr= $pd_p->{'Serial Number'};
    $watch_info->{'Size'}= my $size= $pd_p->{'Size'};

    my $wipe_info= "wiped/$sernr";
    if (-f $wipe_info)
    {
      print "pd=[$pd_id] (sernr=[$sernr]) already wiped, skipped!\n";
      next;
    }

    foreach my $ld_id (keys %{$array->{'ld_id'}})
    {
      my $ld_p= $array->{'ld_id'}->{$ld_id};
      my ($status, $dev_path)= map { $ld_p->{$_}; } ('Status', 'Disk Name');

      unless ($status eq 'OK')
      {
        print "pd=[$pd_id] (sernr=[$sernr]) status='$status', skipped\n";
	next;
      }

      my $job_file= "jobs/$pd_id";
      $watch_info->{'job_file'}= $job_file;
      if (-f $job_file)
      {
        # $watch_info->{'pid'}= $pid; TODO: need to read job file to get that info!
        $watch_info->{'forked'}= 0;
	my ($ji, $prog)= &examine_job ($watch_info);
# print __LINE__, " prog=[$prog]\n";

        my $status;
	if ($prog == 1)
	{
	  $status= 'finished';
	  $finished{$pd_id}= $watch_info;
	}
	else
	{
	  $status= 'running';
	  $job_count++;
	}
        $watch_info->{'status'}= $status;

	my $prog_pct= $prog*100.0;

        print "pd=[$pd_id] (sernr=[$sernr]) currently being wiped, status=$status progress=$prog_pct%, skipped\n";
	next;
      }

      my $pid= fork ();
      if ($pid == 0)
      {
        # &perform_wipe ($array, $pd_id, $dev_path, $sernr);
	my $cmd= "/usr/bin/shred -v -n 7 -z '$dev_path'";

	my $start_e= time ();
	my $start= scalar localtime ($start_e);
	my $pid= $$;
        my $log_file= "jobs/$pid";

        open (JOB_FILE, '>' . $job_file) or die;
        print JOB_FILE <<EOX;
pid       $pid
log_file  $log_file
pd_id     $pd_id
dev_path  $dev_path
sernr     $sernr
started   $start
start_e   $start_e
cmd       $cmd
wtype     shred
size      $size
EOX

        # print JOB_FILE "rc        $rc\n";
        print JOB_FILE '-'x 72, "\n";
        print JOB_FILE 'array= ', Dumper ($array), "\n";
	close (JOB_FILE);

        print "sleeping $SLEEP_TIME seconds; next: $cmd\n";
        sleep ($SLEEP_TIME);

        # real wiping starts here
	my $rc= system ("$cmd >$log_file 2>&1");

	my $stop_e= time ();
	my $stop= scalar localtime ($stop_e);

        print "pd=[$pd_id] (sernr=[$sernr]) finished, rc=$rc, $stop\n";

        my ($prog, $errors, $unknown)= &examine_job_progress ($log_file); # EJP
        print "$log_file prog=$prog errors='$errors' unknown='$unknown'\n";

        open (JOB_FILE, '>>' . $job_file) or die;
        print JOB_FILE '-'x 72, "\n";
        print JOB_FILE <<EOX;
stopped   $stop
stop_e    $stop_e
progress  $prog
errors    $errors
unknown   $unknown
EOX
	close (JOB_FILE);

	exit (0);
      }
      elsif ($pid >= 0)
      {
        $watch_info->{'pid'}= $pid;
        $watch_info->{'status'}= 'running';
        $watch_info->{'forked'}= 1;

        print "forked wipe job pid='$pid'\n";
	$fork_count++;
      }
      else
      {
        print "ATTN: fork failed! $@\n";
      }
    }

  }

  # print 'pd_watch=', Dumper ($pd_watch), "\n";

  ($fork_count, $job_count, \%finished);
}

# AQW
sub examine_job
{
  my $watch_info= shift;

  my $job_file= $watch_info->{'job_file'};
  my ($ji, $progress)= &examine_job_file ($watch_info, $job_file);
  $watch_info->{'job_info'}= $ji;

print __LINE__, " progress='$progress'\n";
# print "ji: ", Dumper ($ji), "\n";
print "watch_info: ", Dumper ($watch_info), "\n";
  ($ji, $progress);
}

sub examine_job_file
{
  my $watch_info= shift;
  my $job_file= shift;

  my $ji= {};
  open (JOB_FILE, $job_file) or return undef;
  while (<JOB_FILE>)
  {
    chop;
    last if (m#^-----*$#); # rest of file contains array object
    my ($an, $av)= split (' ', $_, 2);
    $ji->{$an}= $av;
  }
  close (JOB_FILE);

  my ($progress, $prog, $errors, $unknown);
  if (exists ($ji->{'pid'}))
  {
    my $pid= $watch_info->{'pid'}= $ji->{'pid'};
    my $log_file= $watch_info->{'log_file'}= "jobs/$pid";

    ($prog, $errors, $unknown)= &examine_job_progress ($log_file);

    $progress= ($errors || $unknown) ? 0 : $prog;

    $watch_info->{'progress'}= $progress;
    $watch_info->{'prog'}= $prog;
    $watch_info->{'errors'}= $errors;
    $watch_info->{'unknown'}= $unknown;
  }

  ($ji, $progress);
}

# EJP
sub examine_job_progress
{
  my $fnm= shift;

  my $progress= undef;
  my $errors= 0;
  my $unknown= 0;

  open (JP, $fnm) or return undef;
# print "reading job progress [$fnm]\n";
  while (<JP>)
  {
    chop;
# progress info: /usr/bin/shred: /dev/cciss/c0d1: pass 1/8 (random)...479MiB/34GiB 1%

# print "[$_]\n";

    if (m#.+/shred.*: ([^:]+): pass (\d+)/(\d+) \(([^)]+)\)\.\.\.\S+ (\d+)\%#)
    {
      my ($dev, $pass, $passes, $mode, $pct)= ($1, $2, $3, $4, $5);
      $progress= ($pass-1)/$passes + ($pct/100)/$passes;
    }
    elsif (m#.+/shred.*: ([^:]+): pass (\d+)/(\d+) \(([^)]+)\)\.\.\.$#)
    {
      my ($dev, $pass, $passes, $mode)= ($1, $2, $3, $4);
      $progress= ($pass-1)/$passes; # start of a new pass
      next;
    }
    elsif (m#.+/shred.*: ([^:]+): fdatasync failed: Input/output error#)
    {
      $errors++;
    }
    else
    { print __LINE__, " >>> progress info: ", $_, "\n";
      $unknown++;
    }
  }
  close (JP);
  ($progress, $errors, $unknown);
}

sub mark_wiped
{
  my $acu= shift;

  my $deleted= 0;
  foreach my $pd_id (@pd_wiped)
  {
    my $pd_array= $acu->{'pd_id'}->{$pd_id};
    my $array= $acu->{'array'}->{$pd_array};

    my $pd_p= $array->{'pd_id'}->{$pd_id};
    # print "pd_p=", Dumper ($pd_p), "\n";
    my $sernr= $pd_p->{'Serial Number'};

    my $wipe_info= "wiped/$sernr";
    if (-f $wipe_info)
    {
      print "pd=[$pd_id] (sernr=[$sernr]) already wiped, skipped!\n";
      next;
    }

    my @lds= sort keys %{$array->{'ld_id'}};

    print "marking drive '$pd_id' (sernr=[$sernr] in array '$pd_array' (lds=[", join (',', @lds), "]) as wiped\n";
    open (FO, '>' . $wipe_info) or die;
    print FO Dumper ($pd_p), "\n";
    close (FO);
    foreach my $ld_id (@lds)
    {
      $acu->ld_delete ($ld_id);
    }
  }

  if ($deleted)
  {
    &read_config ($acu);
  }
}

sub create_arrays
{
  my $acu= shift;

  my $pd_watch= $acu->{'pd_watch'};

  if (defined ($pd_watch) && exists ($acu->{'array'}->{'unassigned'}))
  {
    my $ua= $acu->{'array'}->{'unassigned'}->{'pd_id'};
    my $created= 0;
    foreach my $pd_ua (sort keys %$ua)
    {
      my $watch_info= $pd_watch->{$pd_ua};
      next unless (defined ($watch_info));

      my $pd_ua_p= $ua->{$pd_ua};
      my $sernr= $pd_ua_p->{'Serial Number'};

      if (-f "wiped/$sernr")
      {
        print "unassigned pd=[$pd_ua] (sernr=[$sernr]) already wiped, skipped!\n";
        next;
      }

      # print "unassigned pd=[$pd_ua] ", Dumper ($ua->{$pd_ua}), "\n";
      $acu->ld_create ($pd_ua);
      $created++;
    }

    if ($created)
    {
      &read_config ($acu);
    }
  }
}


sub read_config
{
  my $acu= shift;

  $acu->reset ();
  $acu->get_config ();

  if ($cache == 1)
  {
    open (FO, '>' . $conf_dump) or die;
    print FO Dumper ($acu), "\n";
    close (FO);
  }

  # print "acu: ", Dumper ($acu), "\n";

}

sub ts
{
  my $t= shift || time ();
  my @t= localtime ($t);

  sprintf ("%04d%02d%02dT%02d%02d%02d",
    $t[5]+1900, $t[4]+1, $t[3],
    $t[2], $t[1], $t[0]);
}

__END__

=head1 TODO
* option for passing hpacucli output to STDOUT

* watch loop with waitpid for forked processes; already running processes can be watched too;

* reporting by mail (and/or otherwise), especially while in watch loop, waiting for new disks

* parsing shred logs for defective disks [done for one error type]
* handling/reporting of defective disks

=head1 NOTES

=head2 watch info

  status :=
    running     ... wipe process in progress
    finished    ... wipe process is already finished, waiting for disk change XXX
    empty       ... no disk in slot
    defective   ... disk in slot is defective

  started := time () when process was forked
  finished := time () when forked process terminated
  pct_complete := data from shred output
  eta := time when shred is expected to end

