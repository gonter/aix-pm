#!/usr/bin/perl
#
# front end for various NIM (automation) tasks
#
my $VERSION= '$Id: mknim.pl,v 1.18 2013/07/26 10:18:41 gonter Exp $';
#

=pod

=head1 NAME

mknim -- perform various NIM tasks

=head1 SYNOPSIS

This script is intended to automate a few NIM administration tasks.
It\'s current main purpose is to automate periodic mksysb jobs.

See usage clause below.

=cut

use strict;

use lib '/root/work/perl';

use AIX::NIM::Config;
use AIX::odm;
use Util::ts;
use FileHandle;

use Data::Dumper;
$Data::Dumper::Indent= 1;
# sub print_refs { local *F= shift; print F $_[0], ' ', Dumper ($_[1]), "\n"; }

# Configuration
my $server= 'master';
my $DEFAULT_MKSYSB_LOCATION= '/export/mksysb';
my $POLICY_FILE= '/etc/nimpolicy';
my $POLICY_FILE_fixmirr= '/etc/fixpolicy';
my $FORCE= 0;
my $MAIL= '/usr/bin/mail';
my $LSNIM= '/usr/sbin/lsnim';
my $genpassw= '/usr/local/bin/genpassw';

# BEGIN eventlog report_event
my $wget= '/usr/local/bin/wget';
my $event_base= undef;
# END eventlog report_event

# Setup
my $doit= 0;
my $verbose= 1;
my $print= 1;
my $FS_SEP= '/';  # filesystem path separator
my $SEP= '_';     # separator for mksysb objects
my %NIM_TASK= (); # time of last trial
my $client_directory= '/export/fixes/clients'; # Todo: into policy file

# policy handling/refreshing
# these variables are populated by calling &refresh_policy ();
my $policy;
my $policy_mtime= 0;
my $report_email;
my @AUTO_MKSYSB_SERVER= (); # list of servers that perform mksysb backups
my $AUTO_MKSYSB_ACTIVE; # flag: true means that mksysb images should be done
my $AUTO_SLEEP_TIME; # in seconds, default set in refresh_policy ();
my $MKSYSB_TIMEOUT; # in seconds

my @REPORT;

# runtime flags
my $nim_updated= 0;

my $op= 'none';
my $client;
my $arg;
while ($arg= shift (@ARGV))
{
  if ($arg =~ /^-/)
  {
       if ($arg =~ /^-(mksysb|cleanup|tasks|auto|lslpp)/) { $op= $1; }
    elsif ($arg eq '-c') { $client= shift (@ARGV); }
    elsif ($arg eq '-s') { $server= shift (@ARGV); }
    elsif ($arg eq '-F') { $FORCE= 1; }
    elsif ($arg eq '-L') { $DEFAULT_MKSYSB_LOCATION= shift (@ARGV); }
    elsif ($arg eq '-doit') { $doit= 1; }
    else { &usage (); exit (0); }
    next;
  }
}

&refresh_policy ();

if ($op eq 'mksysb')
{
  unless ($server && $client)
  {
    &usage ();
    exit (0);
  }

  &gen_mksysb ($server, $client);
}
elsif ($op eq 'auto')
{
  &auto_tasks ();
}
elsif ($op eq 'tasks')
{
  # -------------------------------------------------------------
  # Read the "policy" file which describes attributes about the
  # current NIM environment which are not found in NIM itself.  The
  # policy file is a text file which uses the same format as output of
  # lsnim since we already need a parser for that format anyway.
  my $policy= new AIX::NIM::Config;  # prepare NIM config object
  $policy->get_config ($POLICY_FILE);
  ## &print_refs (*STDOUT, 'policy', $policy);

  &list_next_tasks ($policy, $server);
}
elsif ($op eq 'cleanup')
{
  &cleanup_mksysb ();
  &cleanup_exclude_files ();
}
elsif ($op eq 'lslpp')
{
  &lslpp_machines ();
}
else
{
  print "no operation specified\n";
  &usage ();
}

if (@REPORT)
{
  print '='x64, "\n";
  print "ATTENTION:\n";
  foreach (@REPORT) { print $_, "\n"; }
  print '='x64, "\n";
}
exit (0);

# ======================================================================
sub usage
{
  print <<"=cut";

=pod

=head1 USAGE

mknim.pl (-commands) [-options]

Commands:
-auto      perform periodic tasks in a loop
-mksysb    make a backup using mksysb

Options:
-doit      perform real work
-tasks     show next task
-F         force (for mksysb, in case the target filesystem is not large enough)

-mksysb
  -c client  [required]
  -s server  [optional]

Examples:

mknim.pl -auto -F -doit
... standard daemon mode

mknim.pl -mksysb -c nim-client-name -doit
... create backup just for one client, now

=cut

}

sub lslpp_machines
{

  my $policy= new AIX::NIM::Config;
  $policy->get_config ($POLICY_FILE_fixmirr);

  my $fixmirr= $policy->get_object ('fixmirr');
print "fixmirr='$fixmirr'\n";

  my $lpp_dir= ($fixmirr->av ('lpp_dir'))[0];
print "lpp_dir: ", $lpp_dir, "\n";

  my @machines= $fixmirr->av ('client');
print "machines: ", join (', ', @machines), "\n";

  my $cnf= new AIX::NIM::Config;
  $cnf->get_class_config ('machines');

  my @not_defined;
  my $machine;
  foreach $machine (@machines)
  {
    print "  client = $machine\n";
    my $mo= $cnf->get_object ($machine);
    unless (defined ($mo))
    {
      push (@not_defined, $machine);
      next;
    }

    my ($net, $hostname)= $mo->get_hostname (); # assumes if1

    &do ("rsh $hostname 'lslpp -Lc all' >$client_directory/$machine");
    &do ("rsh $hostname 'oslevel -r' >$client_directory/$machine.oslevel");
  }

  if (@not_defined)
  {
    push (@REPORT, "not defined as a nim object: "
		   . join (', ', @not_defined));
  }
}

sub refresh_policy
{
  my @policy_stat= stat ($POLICY_FILE);

  if ($policy_mtime < $policy_stat[9])
  {
    $policy= new AIX::NIM::Config;  # prepare a fresh NIM config object
    $policy->get_config ($POLICY_FILE);
    $policy_mtime= $policy_stat[9];

    my $admin= ($policy->select_objects ('class' => 'policy', 'type' => 'admin'))[0];
    $report_email= join (',', $admin->av ('notify_mail'));
    $event_base= ($admin->av ('event_base'))[0];

    my $mksysb_server= ($policy->select_objects ('class' => 'policy', 'type' => 'auto'))[0];
    print "mksysb_server='$mksysb_server'\n";
    @AUTO_MKSYSB_SERVER= $mksysb_server->av ('server');
    $AUTO_MKSYSB_ACTIVE= $mksysb_server->av ('active');
    $AUTO_SLEEP_TIME= $mksysb_server->av ('sleep') || 300;
    $MKSYSB_TIMEOUT= $mksysb_server->av ('mksysb_timeout') || 10800;
  }
}

sub auto_tasks
{
  &report_event ('agent' => 'mknim', 'action' => 'start', 'task' => 'auto_tasks');

  while (1)
  {
    &refresh_policy ();

    unless ($AUTO_MKSYSB_ACTIVE eq 'true')
    {
      print "auto stanza, flag active is not set to \"true\";\n";
      my $sleep= $AUTO_SLEEP_TIME;
      print "sleeping $sleep seconds, ", &ts_ISO(), " until ", &ts_ISO(time()+$sleep), "\n";
      sleep ($sleep);
      next;
    }

    my $start= time ();
    my $srv;
    foreach $srv (@AUTO_MKSYSB_SERVER)
    {
      &list_next_tasks ($policy, $srv);
    }

    my $stop= time ();
    my $sleep= $AUTO_SLEEP_TIME + $start - $stop;
    if ($sleep > 0)
    {
      print "sleeping $sleep seconds, ", &ts_ISO(), " until ", &ts_ISO(time()+$sleep), "\n";
      sleep ($sleep);
    }

    # print updated nim configuration
  }

  &report_event ('agent' => 'mknim', 'action' => 'stop', 'task' => 'auto_tasks');
}

# list upcoming tasks on a given server
sub list_next_tasks
{
  my $policy= shift;
  my $srv= shift;

  print "mksysb tasks of server '$srv'\n";
  my @srv_obj= $policy->select_objects ('class' => 'policy', 'type' => 'client_group', 'server' => $srv);

  if (@srv_obj < 1)
  {
    print "no object for server '$srv'\n";
    return undef;
  }

  if (@srv_obj > 1)
  {
    print "multiple server definitions! in ", $policy->{'_source_'}, "\n";
  }

  &list_next_tasks_object ($policy, $srv, shift (@srv_obj));
}

# this actually performs one task, if possible!
sub list_next_tasks_object
{
  my $policy= shift;
  my $srv= shift;
  my $srv_obj= shift;

  my @clients= $srv_obj->av ('machine');
  my ($generations, $max_age, $g_busy)= map { $srv_obj->av ($_); } qw(generations max_age busy);

  my %clients= ();
  map { $clients{$_}= { 'machine' => $_, 'wanted' => 1, 'backups' => {} }; } @clients;

  print "clients: ", join (', ', sort keys %clients), "\n";

  # strange, mksysb objects do not contain the name of the machine that was backed up
  # so we need a complete list of all mksysb objects and infer the name of the
  # machine that was backup-up from that name
  my $mksysb= new AIX::NIM::Config;
  $mksysb->get_type_config ('mksysb');
  my @n_mksysb= $mksysb->get_object_names ();

  my %backups;

  my $msb;
  foreach $msb (@n_mksysb)
  {
    if ($msb =~ /^msb_/)
    {
## print "msb: $msb\n";
      my ($x1, $x_client, $x_server, $x_ts)= split ('_', $msb);
      my $c;
      if (defined ($c= $clients{$x_client}) && $x_server eq $srv)
      {
	## printf ("%-12s %-12s %-12s %s\n", $x_client, $x_server, $x_ts, $msb);
	$c->{'backups'}->{$x_ts}= $msb;
	push (@{$backups{$x_ts}}, [$c, $x_client, $x_server, $x_ts, $msb]);
      }
    }
  }

  my $ts_max_age= &ts_ISO (time () - 86400 * $max_age);
  my $marker_printed= 0;

  my $ts;
  foreach $ts (sort keys %backups)
  {
    my $p= $backups{$ts};
    my $pp;
    foreach $pp (@$p)
    {
      my ($c, $x_client, $x_server, $x_ts, $msb)= @$pp;

      if (!$marker_printed && $x_ts gt $ts_max_age)
      {
        printf ("%-12s %-12s %-12s %s\n", '*'x12, '*'x12, $ts_max_age, '*'x36);
	$marker_printed= 1;
      }

      printf ("%-12s %-12s %-12s %s\n", $x_client, $x_server, $x_ts, $msb);
    }
  }

  ## print_refs (*STDOUT, 'clients', \%clients);
  my @need_backup= &find_old_backups (\%clients, $generations, $max_age);
  print "need_backup: ", join (', ', @need_backup), "\n";
  my $client;
  foreach $client (@need_backup)
  {
    my $c_busy= $g_busy;
## print __LINE__, " >>> client=[$client] g_busy=[$g_busy]\n";

    my @client_obj= $policy->select_objects ('class' => 'policy',
                      'type' => 'client', 'machine' => $client);

## print __LINE__, " >>> client=[$client] client_obj: ", Dumper (\@client_obj);

    my $client_obj= shift (@client_obj);
    if (defined ($client_obj))
    {
      $c_busy= $client_obj->av ('busy');
    }

    if ($c_busy && &busy ($c_busy))
    {
      print "busy: $c_busy $client\n";
      next;
    }

    my $rc= &gen_mksysb ($srv, $client, $client_obj);
    last if ($rc); # only one job is really performed
  }

  ## print_refs (*STDOUT, 'backups', \%backups); zawos?
}

sub busy
{
  my $b= shift;

  my @t= localtime (time ());
  my $t= sprintf ("T%02d%02d%02d", $t[2], $t[1], $t[0]);
  my @b= split(/-/, $b);
  # print "busy TS: ", join (' ', @b, $t), "\n";
  return ($b[0] lt $t && $t lt $b[1]);
}

# find and possibly remove old/unneeded backups and also
# return a list of hosts that need backups;  This list is ordered
# by the age of the host's newest backups
sub find_old_backups
{
  my $clients= shift;
  my $generations= shift;
  my $max_age= shift;

  my %need_backup= ();
  my $ts_max_age= &ts_ISO (time () - 86400 * $max_age);

  print "generations: $generations, max_age: $max_age, ts_max_age=$ts_max_age\n";
  my $c;
  foreach $c (sort keys %$clients)
  {
    my $cp= $clients->{$c};
    my @backups= sort keys %{$cp->{'backups'}};

    while (@backups > $generations)
    {
      my $old= shift (@backups);
      my $msb= $cp->{'backups'}->{$old};
      print "old backup $c $old $msb\n";
      &remove_mksysb ($msb);
    }

    # remaining backups should be kept
    # find out, if the newst backup is within max_age
    my $newest= pop (@backups);
    push (@{$need_backup{$newest}}, $c) if ($newest lt $ts_max_age);
  }

  my $ts_backup;
  my @need_backup;
  foreach $ts_backup (sort keys %need_backup)
  {
    my @clients= @{$need_backup{$ts_backup}};
    $ts_backup= 'missing' unless ($ts_backup);
    print "$ts_backup: ", join (', ', @clients), "\n";
    push (@need_backup, @clients);
  }

  return @need_backup;
}

sub remove_mksysb
{
  my $msb= shift;

  my $MSBc= new AIX::NIM::Config ('verbose' => 1);
  $MSBc->get_object_config ($msb);
  my ($MSBo)= $MSBc->get_objects ();
 
# ZZZ
  my $location= $MSBo->av ('location');
  my $server= $MSBo->av ('server');

  # assume we are on master
  if ($server eq 'master')
  {
    print "# removing old mksysb backup $location $msb\n";
    &do ("rm $location");
    &do ("nim -o remove $msb");
  }
  else
  {
    my $MSBh= new AIX::NIM::Config (verbose => 1);
    $MSBh->get_object_config ($server);
    my $mo= $MSBh->get_object ($server);
    # print "# MSBh=[$MSBh] ", Dumper ($MSBh);
    my ($net, $msb_host)= $mo->get_hostname (); # assumes if1

    print "# REMOTE: server=[$server] msb_host=[$msb_host] net=[$net]\n";
    print "# removing old mksysb backup $location $msb\n";

    my $cmd= "rsh $msb_host rm '$location'";
    print "# >>> cmd=[$cmd]\n";

    &do ($cmd);
    &do ("nim -o remove $msb");
  }

  $nim_updated++;
}

sub cleanup_mksysb
{
  &cleanup_object_location ('mksysb', $DEFAULT_MKSYSB_LOCATION);
}

sub cleanup_exclude_files
{
  &cleanup_object_location ('exclude_files');
}

sub cleanup_object_location
{
  my $object_type= shift;
  my $default_location= shift;

  my $nim= new AIX::NIM::Config;
  $nim->get_type_config ($object_type);
  my @O= $nim->get_objects ();
  my $O;

  my %FILE_FOUND= ();
  foreach $O (@O)
  {
    my ($name, $srv, $loc)= map { $O->av ($_); } qw(_name_ server location);
    # print join (' ', $name, $srv, $loc), "\n";
    # print_refs (*STDOUT, 'O', $O);

    # let's assume we are on the master...
    if ($srv eq 'master')
    {
      if (-r $loc)
      {
## print __LINE__, " $loc\n";
	$FILE_FOUND{$loc}= 1;
      }
      else
      {
	print "# $name file not found: $loc\n";

	my @r= AIX::odm::get ('vx_task', "status=running and operation=$object_type and par2=$name");
	if (@r > 0)
	{
	  print "$object_type currently in progress\n";
	  print join ("\n", @r), "\n";
	}
	else
	{
          &do ("nim -o remove $name");
          $nim_updated++;
        }
      }
    }
  }

  if ($default_location)
  {
    opendir (DIR, $default_location) || die "cant read dir $default_location";
    my $e;
    while ($e= readdir (DIR))
    {
      next if ($e eq '.' || $e eq '..');
# SS
      my $fp= "$default_location/$e";
      if (-f $fp && !exists ($FILE_FOUND{$fp}))
      {
        print "unaccounted file: $fp\n";
      }
    }
    closedir (DIR);
  }
}

sub gen_mksysb
{
  my $server= shift;
  my $client= shift;
  my $client_obj= shift;

## print __LINE__, " >> gen_mksysb (server=[$server], client=[$client] client_obj= ", Dumper ($client_obj);

  my $t= time ();
  my $now= &ts_ISO ($t);

  my $nim_task= join ($SEP, 'msb', $client, $server);
  my $last_attempt= $NIM_TASK{$nim_task};
  my $next_attempt= $last_attempt+3600;
## print __LINE__, " >>> now=[$now] last_attempt=[$last_attempt] next_attept=[$next_attempt]\n";
  if ($next_attempt >= $t)
  {
    print $now, " task $nim_task attempted at ", &ts_ISO ($last_attempt),
	  " next attempt at ", &ts_ISO ($next_attempt), "\n";
    return 0;
  }
  $NIM_TASK{$nim_task}= $t;

  my $nim_object=     join ($SEP, 'msb', $client, $server, $now);
  my $mksysb_file=    join ($SEP, 'msb', $client, $now);
  my $exclude_object= join ($SEP, 'excl', $client);

  my $location=       join ($FS_SEP, $DEFAULT_MKSYSB_LOCATION);

  system ("mkdir -p '$location'") unless -d ($location);
  $location= join ($FS_SEP, $location, $mksysb_file);

## print __LINE__, "\n";
  my @failure;

  # TODO: check if client is defined as a NIM object
  my $MO= new AIX::NIM::Config ('object' => [$client, $server, $exclude_object]);
  my $co= $MO->get_object ($client);
  push (@failure, "missing NIM object for client '$client'")
    unless (defined ($co));

  # check if exclude_file is defined as a NIM object
  my $xo= $MO->get_object ($exclude_object);
  push (@failure, "missing exclude object '$exclude_object' for client '$client'")
    unless (defined ($xo));

  # TODO: read exclude file (maybe check also check it's syntax) and attach
  # this version at the end of the log file
  my $xf_location= $xo->av ('location');

  # check if server is defined at all
  my $so= $MO->get_object ($server);
  push (@failure, "missing NIM object for server '$server' for client '$client'")
    unless (defined ($so));

  # check if client can see the server via NFS
  if ($co && $so && $client ne 'wickerl-lpar1' && $client ne 'ppb-i')
  {
    my ($c_net, $c_host)= $co->get_hostname ();
    my ($s_net, $s_host)= $so->get_hostname ();
## print __LINE__, " >>> c_net='$c_net' c_host='$c_host s_net='$s_net' s_host='$s_host'\n";

    unless ($c_host)
    {
      push (@failure, "no hostname defined for $client");
      goto OUT;
    }

    unless ($s_host)
    {
      push (@failure, "no hostname defined for $server");
      goto OUT;
    }

    my $test_command= "rsh $c_host 'showmount -e $s_host'";
## print __LINE__, " >>>> ", $test_command, "\n";
    my $ts_t_start= time ();
    my $r1= `$test_command 2>&1`;
    my $ts_t_duration= time () - $ts_t_start;
## print __LINE__, " duration=$ts_t_duration ", $r1, "\n";

    if ($ts_t_duration > 5)
    {
      push (@failure, "test too long: $ts_t_duration seconds for $test_command");
    }

    if ($r1 =~ /RPC: (\d+-\d+)\s*(.*)/)
    {
      my ($err_code, $err_msg)= ($1, $2);
      my $err_class= 'failure';

      if ($err_code eq '1832-019')
      { # RPC: 1832-019 Program not registered
	$err_class= 'note';
	# Todo: this may be worth noting in the report mail
      }

      if ($err_class eq 'failure')
      {
        push (@failure, "result for $test_command:", $r1);
      }
    }
  }

OUT:

  ## print "so='$so' co='$co' xo='$xo'\n";

  # definition of mksysb object, see AIX manual pages 295, 296
  my $cmd= "nim -o define -t mksysb -a server=$server"
           . " -a location=$location"
           . " -a mk_image=yes -a source=$client"
           . " -a exclude_files=$exclude_object";

  $cmd .= " -F" if ($FORCE);
  $cmd .= " $nim_object";

  my $task_id= `$genpassw -A`;
  chop ($task_id);
  my $ts_started= $now;

# ZZ
  if (@failure)
  {
    print "failure!\n";
    if (open (MAIL, "|$MAIL -s 'nim backup failure $nim_object' '$report_email'"))
    {
      foreach (@failure)
      {
        print      $_, "\n";
        print MAIL $_, "\n";
      }

      close (MAIL);
    }
    return 0;
  }
  my @add;

  if ($doit)
  {
    my $d=
    {
      'task_id' => $task_id,
      'ts_started' => $ts_started,
      'status' => 'running',
      'pid' => $$,
      'operation' => 'mksysb',
      'par1' => $client,
      'par2' => $nim_object,
      'comment' => $cmd,
    };

    @add= AIX::odm::add ('vx_task', $d);
    &report_event ('task' => 'mksysb', 'agent' => 'mknim', %$d);

    if ($report_email && $MAIL)
    {
      if (open (MAIL, "|$MAIL -s 'nim backup start $nim_object' '$report_email'"))
      {
        foreach (@add) { print MAIL $_, "\n"; }
  
        close (MAIL);
      }
    }
  }

  my $log_file= "/var/log/vx_task/$task_id";
  print "starting task $task_id; log_file=$log_file\n";
  print $cmd, "\n" if ($print);

  if (open (LOGFILE, ">$log_file"))
  {
    print LOGFILE <<EOX;
backup start: $ts_started
cmd: $cmd

exclude_file: $xf_location

BEGIN_LOG
EOX
    close (LOGFILE)
  }

  my $rc= system ("$cmd >>$log_file 2>&1") if ($doit);
  $nim_updated++;

  if ($doit && 0)
  {
    my $res;

    eval
    {
      # alarm ($mksysb_timeout);
      my $res= `$cmd 2>&1`;
      # alarm (0);
    };

    print $res, "\n";
  }

  my $ts_finished= &ts_ISO;

  # TODO: Analyze log file to check if there are known error patterns
  #       which can be ignored.  The error code may be changed in such
  #       a situation to allow better problem tracking without too
  #       many false alarms.

  if (open (LOGFILE, ">>$log_file"))
  {
    print LOGFILE <<EOX;
END_LOG
backup finished: $ts_finished
rc: $rc
EOX

    if (open (XF, $xf_location))
    {
      print LOGFILE "\nexclude_file $xf_location\nBEGIN\n";
      while (<XF>)
      {
	print LOGFILE $_;
      }
      print LOGFILE "\nEND\n";
      close (XF);
    }
    else
    {
      print "\n exclude_file $xf_location not readable\n";
    }

    close (LOGFILE);
  }

  if ($doit && $report_email && $MAIL)
  {
    my $c=
    {
      'status' => 'finished',
      'ts_finished' => $ts_finished,
      'result' => $rc,
    };
    my @change= AIX::odm::change ('vx_task', "task_id='$task_id'", $c);
    &report_event ('task' => 'mksysb', 'agent' => 'mknim',  %$c);

    if (open (MAIL, "|$MAIL -s 'nim backup finished $nim_object' '$report_email'"))
    {
      autoflush MAIL 1;
      &transcribe_file (*MAIL, $log_file);

      print MAIL "\n\n", "-"x30, "\n\n";

      foreach (@add) { print MAIL $_, "\n"; }
      foreach (@change) { print MAIL $_, "\n"; }

      my $lsnim= "$LSNIM -l $nim_object";

      print MAIL <<EOX;
lsnim: $lsnim
EOX

      my $lsnim_res= `$lsnim`;
      print MAIL $lsnim_res, "\n";

      close (MAIL);
    }
  }

  return 1; 
}

sub transcribe_file
{
  local *FO= shift;
  my $fnm= shift;

  local *FI;
  unless (open (FI, $fnm))
  {
    print FO "ERROR: cant open $fnm [", $@, "]\n";
    return;
  }

  print FO "FILE $fnm\n";

  while (<FI>) { print FO $_; }

  close (FI);
}

sub do
{
  my $cmd;
  foreach $cmd (@_)
  {
    print $cmd, "\n" if ($verbose);
    system ($cmd) if ($doit);
  }
}

sub report_event
{
  my %par= @_;

  return unless (defined ($event_base));
  my $cmd= "'$wget' -O- -o/dev/null '$event_base?"
           . join ('&', map { "$_=".$par{$_}; } sort keys %par) . "'";
  print ">>> cmd='$cmd'\n";
  system ($cmd);
}

__END__

=head1 FILES

/etc/nimpolicy   configuration file in stanza format (same format as
		 generated by lsnim)

=head2 Example Configuration File /etc/nimpolicy

admin:
   class = policy
   type = admin
   rcs_tag =
   notify_mail = nim-admin@example.com
   notify_mail = backup-admin@example.com
   i_am = master
   event_base = http://eventmon.example.com/cgi-bin/eventlog
auto:
   class = policy
   type = auto
   comments = list of NIM mksysb servers to be monitored
   sleep = 420
   mksysb_timeout = 7200
   active = true
   server = master
   server = another-master
clients_master:
   class = policy
   type = client_group
   comments = mksysb clients which are served by master
   max_age = 3
   generations = 2
   server = master
   machine = host-1
   machine = host-2
   machine = host-n
host-1:
   class = policy
   type = client
   comments = one of the hosts, do not backup between 07:00 and 20:00
   machine = host-1
   busy = T070000-T200000

=head1 TODO

More documentation and example files, especially an example policy
file is necessary.  The ODM file vx_task needs also some explanation.

=head2 Known Bugs

The script can not interrupt a mksysb job that is running too long
e.g. hanging process on remote site due to missing file system etc.

=head2 Feature Requests

busy time: allow calendar or at least week day specification

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

See http://aix-pm.sourceforge.net/ for more information.

=over

