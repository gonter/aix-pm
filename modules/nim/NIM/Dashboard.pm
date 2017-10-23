# $Id: Dashboard.pm,v 1.9 2009/09/28 10:57:31 gonter Exp $

package AIX::NIM::Dashboard;

=pod

=head1 NAME

AIX::NIM::Dashboard   --  produce dashbaord-like sumary of NIM configuration

=cut

use strict;
use AIX::odm;
use AIX::VPD::lscfg;
## gibts nimma! use Util::print_refs;
use Util::ts;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $VERSION= '0.02';

my $WARNING_OPEN= '<font color="red">';
my $WARNING_CLOSE= '</font>';

sub new
{
  my $class= shift;

  my $obj=
  {
    'machines' => {},  # NIM names, complete dashboard description about given host
    'dns_names' => {}, # DNS name to NIM name mapping
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

sub get_host
{
  my $obj= shift;
  my $nim_name= shift;
  my %par= @_;

  my $ho;
  unless (defined ($ho= $obj->{'machines'}->{$nim_name}))
  {
    return undef if (exists ($par{'dont_add'}));

    $ho= $obj->{'machines'}->{$nim_name}=
    {
      'nim_name' => $nim_name
    };
  }

  foreach my $par (keys %par)
  {
    $ho->{$par}= $par{$par};
  }

  $ho;
}

sub map_hosts
{
  my $obj= shift;
  my $nim_obj= shift;

  my $machines= $nim_obj->select_objects ('class' => 'machines');
  return undef unless (defined ($machines));

  my $dns= $obj->{'dns_names'};
  foreach my $nho (@$machines)
  {
    my $nim_name= $nho->av ('_name_');
    my $comments= $nho->av ('comments');
    my ($net_name, $host_name)= $nho->get_hostname ();

    my $dho= $obj->get_host ($nim_name);
    $dho->{'dns_name'}= $host_name;
    $dho->{'net_name'}= $net_name;
    $dho->{'is_nim_object'}= 1;

    $dns->{$host_name}= $nim_name; # cross referencing by DNS name
  }

  my $mksysb= $nim_obj->select_objects ('class' => 'resources', 'type' => 'mksysb');
  print "mksysb objects: $mksysb\n";
  return undef unless (defined ($mksysb));

  foreach my $msb (@$mksysb)
  {
    my $nim_name= $msb->av ('_name_');
    if ($nim_name =~ /^msb_([^_]+)_([^_]+)_(\d{8})T(\d{6})$/)
    {
      my ($msb_client, $msb_server, $msb_date, $msb_time)= ($1, $2, $3, $4);
      my $dho= $obj->get_host ($msb_client);
      push (@{$dho->{'mksysb'}->{$msb_server}}, $nim_name);
    }
  }
}

sub map_nim_policy
{
  my $obj= shift;
  my $policy_obj= shift;

  print "mapping nim policy\n";
  # main::print_refs (*STDOUT, 'policy_obj', $policy_obj);
  my $cgs= $policy_obj->select_objects ('class' => 'policy', 'type' => 'client_group');
  foreach my $cg (@$cgs)
  {
    $obj->map_nim_policy_client_group ($cg);
  }

  my $clients= $policy_obj->select_objects ('class' => 'policy', 'type' => 'client');
  foreach my $client (@$clients)
  {
## print __LINE__, " >> client='$client'\n";
    $obj->map_nim_policy_client ($client);
  }
}

sub map_nim_policy_client_group
{
  my $obj= shift;
  my $cg= shift;

  my $name= $cg->av ('_name_');
  my $srv= $cg->av ('server');
  my $max_age= $cg->av ('max_age');
print __LINE__, " > name='$name' srv='$srv' max_age='$max_age'\n";

  print "mapping nim policy client group $name $srv\n";
  # main::print_refs (*STDOUT, 'client_group', $cg);

  my @machines= $cg->av ('machine');
  foreach my $machine (@machines)
  {
print __LINE__, " >>> machine='$machine'\n";
    my $dho= $obj->get_host ($machine, 'max_age' => $max_age, 'msb_group' => $name);
    $dho->{'mknim_group'}->{$name}++;
  }
}

# XXX unfinished, maybe this should be found elsewhere
sub map_nim_policy_client
{
  my $obj= shift;
  my $cg= shift;

  my ($name)= map { $cg->av ($_); } qw(_name_);
## print __LINE__, " >>> name='$name'\n";
  $name;
}

sub map_client_inventories
{
  my $obj= shift;
  my $dir= shift;

  local *DIR;
  my $e;
  opendir (DIR, $dir) or die "map_client_inventories: cant read dir '$dir'";
  while ($e= readdir (DIR))
  {
    next unless ($e =~ /^[\w\d\-\_]+$/);
    my $fp= $dir .'/'. $e;
    next unless (-d $fp);

    my $x= &_map_client_inventory ($fp);
    next unless ($x);

    my $dho= $obj->get_host ($e, 'has_inventory' => 1);
    $dho->{'inventory'}= $x;
  }
  closedir (DIR);
}

sub _map_client_inventory
{
  my $cl_path= shift;

  my $lscfg= "$cl_path/lscfg-pv";
  my @st= stat ($lscfg);
  return undef unless ($st[7]); # ignore inventory if file is empty
  my $cfg= new AIX::VPD::lscfg;
  $cfg->read_lscfg ($lscfg);
  $cfg->read_lsdev_C ("$cl_path/lsdev-C");

  my $res=
  {
    'upd' => $st[9],  # mtime of lscfg file indicates inventory update
    'cfg' => $cfg,
  };
}

sub map_todo_list
{
  my $obj= shift;
  my $fnm= shift;

  open (FI, $fnm) or die "map_todo_list: cant read '$fnm'\n";
  while (<FI>)
  {
    chop;
  }
  close (FI);
}

sub print_dashboard
{
  my $obj= shift;
  my $fo= shift;
  my $nim_cfg_html= shift;

  my $debug= $obj->{'debug'};

  local *F;
  if ($fo eq '-')
  {
    *F= *STDOUT;
  }
  else
  {
    open (F, '>' . $fo) or return undef;
  }

  # statistics:
  my $cnt_log_errors= 0;
  my $cnt_mksysb= 0;
  my $cnt_hosts= 0;
  my $ts_last_mksysb;

  my $status= 'OK'; # TODO: make real status updates

  my $now= time ();
  my $ts= localtime ($now);
  my $ts_iso= &ts_iso ($now);

  my @msb_too_old= ();

  print F <<EOX;
<h1>NIM dashboard</h1>

nim server: xxx<br>
generated: $ts<br>

<table border=1>
<tr>
  <th rowspan=2>machine</th>
  <th rowspan=2>todo</th>
  <th rowspan=2>network</th>
  <th rowspan=2>latest mksysb</th>
  <th colspan=3>inventory</th>
</tr>
<tr>
  <th>type</th>
  <th>sernr</th>
  <th>firmware</th>
</tr>
EOX

  open (DEBUG, '>@DEBUG.nim-dashboard.' . time()) if ($debug);
  foreach my $machine (sort keys %{$obj->{'machines'}})
  {
    $cnt_hosts++;

    my $ho= $obj->get_host ($machine);
    print DEBUG "machine=$machine ho=", Dumper ($ho), "\n" if ($debug);

    my ($nim_name, $is_nim_object, $net_name, $mksysb, $inv, $todo, $max_age)=
       map { $ho->{$_}; } qw(nim_name is_nim_object net_name mksysb inventory todo max_age);

    my $todo= ($todo) ? '<font color="red">*</font>' : '&nbsp;';

    my $msb_line= '&nbsp;';
    if ($mksysb)
    {
      $cnt_mksysb++;
      my ($msb_ts, $msb_info)= &_get_latest_backup ($mksysb);
print __FILE__, ' ', __LINE__, " >>> machine='$machine' msb_ts='$msb_ts' ts_last_mksysb='$ts_last_mksysb'\n";
      my ($msb_date, $msb_time, $msb_name, $task_id, $result, $msb_ts)= @$msb_info;
      $ts_last_mksysb= $msb_ts if ($msb_ts gt $ts_last_mksysb);
      my ($lfo, $lfc);

      if ($result != 0)
      {
	$lfo= $WARNING_OPEN;
	# $lfc= "</font> RES='$result'";
	$lfc= $WARNING_CLOSE;
	$cnt_log_errors++;
      }

      my ($msb_lfo, $msb_lfc);
      if ($max_age)
      {
	my $msb_ts_max= &ts_ISO (time () - 86400 * (1 + $max_age));
	if ($msb_ts < $msb_ts_max)
	{
	  $msb_lfo= $WARNING_OPEN;
	  $msb_lfc= $WARNING_CLOSE;
	  push (@msb_too_old, $machine);
print __FILE__, ' ', __LINE__, " >>>> too_old: machine='$machine' msb_ts='$msb_ts' msb_ts_max='$msb_ts_max'\n";
	}
      }

      $msb_line= join (' ', $msb_lfo, $msb_date, $msb_time, $msb_lfc);
      $msb_line .= " <a href=\"$nim_cfg_html#$msb_name\" target=\"nim_cfg\">obj</a> ";
      $msb_line .= ($task_id) ? "<a href=\"vx_task/$task_id\">${lfo}log${lfc}</a>" : 'NOLOG';
    }
print __LINE__, " >>> machine='$machine' ts_last_mksysb='$ts_last_mksysb'\n";

    my $machine_type= '&nbsp;';
    my $serial_number= '&nbsp;';
    my $firmware= '&nbsp;';
    if ($inv)
    {
      ($machine_type, $serial_number, $firmware)= $inv->{'cfg'}->get (qw(machine_type serial_number firmware));
      $serial_number= join ('-', $1, $2) if ($serial_number =~ /^([\dA-Z]{2})([\dA-Z]{5})$/);
      $serial_number= "<a href=\"clients/$nim_name/lscfg-pv\">$serial_number</a>";
    }

    my $s_nim_name= $nim_name;
    my $s_net_name= '&nbsp;';
    if ($is_nim_object)
    {
      $s_nim_name= "<a href=\"$nim_cfg_html#$nim_name\" target=\"nim_cfg\">$nim_name</a>";
      $s_net_name= "<a href=\"$nim_cfg_html#$net_name\" target=\"nim_cfg\">$net_name</a>";
    }

    print F <<EOX;
<tr>
  <td>$s_nim_name</td>
  <td>$todo</td>
  <td>$s_net_name</td>
  <td>$msb_line</td>
  <td>$machine_type</td>
  <td>$serial_number</td>
  <td>$firmware</td>
</tr>
EOX
  }
  close (DEBUG) if ($debug);

  print F <<EOX;
</table>
EOX

  my ($msb_too_old_list, $msb_too_old_cnt);
  if ($msb_too_old_cnt= scalar @msb_too_old)
  {
    $msb_too_old_list= join (' ', @msb_too_old);
  }

  print F <<EOX;
<h1>Statistics</h1>

<p>
This section is intended for automated processing, e.g. a Nagios
plugin, which could check if the dashboard and mknim are running fine.
</p>

<table border=1>
  <!--Nagios--><tr><td>status</td><td>$status</td></tr>
  <!--Nagios--><tr><td>last_dashboard</td><td>$ts_iso</td></tr>
  <!--Nagios--><tr><td>last_mksysb</td><td>$ts_last_mksysb</td></tr>
  <!--Nagios--><tr><td>cnt_hosts</td><td>$cnt_hosts</td></tr>
  <!--Nagios--><tr><td>cnt_mksysb</td><td>$cnt_mksysb</td></tr>
  <!--Nagios--><tr><td>log_errors</td><td>$cnt_log_errors</td></tr>
  <!--Nagios--><tr><td>msb_too_old_cnt</td><td>$msb_too_old_cnt</td></tr>
  <!--Nagios--><tr><td>msb_too_old_list</td><td>$msb_too_old_list</td></tr>
</table>
EOX

  close (F) if ($fo ne '-');
}

# XXX: maybe this should be a method of a host object
sub _get_latest_backup
{
  my $mksysb= shift;

  my %msb;
  foreach my $srv (keys %$mksysb)
  {
    foreach my $msb (@{$mksysb->{$srv}})
    {
      if ($msb =~ /^msb_([^_]+)_([^_]+)_(((\d{4})(\d{2})(\d{2}))T((\d{2})(\d{2})(\d{2})))$/)
      {
        my ($msb_client, $msb_server,
	    $msb_ts,
	    $msb_date, $msb_yr, $msb_mon, $msb_day,
	    $msb_time, $msb_hr, $msb_min, $msb_sec)= ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);

	my $msb_date2= join ('-', $msb_yr, $msb_mon, $msb_day);
	my $msb_time2= join (':', $msb_hr, $msb_min, $msb_sec);

        $msb{$msb_ts}= [ $msb_date2, $msb_time2, $msb, $msb_date, $msb_time, $msb_ts];
      }
    }
  }

  # locate the latest backup info
## main::print_refs (*STDOUT, 'msb', \%msb);
  my @msb= sort keys %msb;
  my $latest= $msb[$#msb];
  my $msb= $msb{$latest};

  # retrieve vx_task information about that backup job
  my $l_msb_name= $msb->[2];
  print __LINE__, " >>> l_msb_name='$l_msb_name'\n";
  my @r= AIX::odm::get ('vx_task', "par2=$l_msb_name");
## main::print_refs (*STDOUT, 'r', \@r);
  my ($task_id, $result);
  foreach (@r)
  {
    if (/task_id =\s+"(.+)"/) { $task_id= $1; }
    elsif (/result =\s+"(.+)"/) { $result= $1; }
  }
  $msb->[3]= $task_id;
  $msb->[4]= $result;

## main::print_refs (*STDOUT, 'msb', $msb); exit(0);

  return ($latest, $msb);
}

sub ts_iso
{
  my $t= shift;
  my @t= localtime ($t);
  sprintf ("%4d%02d%02dT%02d%02d%02d", 1900+$t[5],$t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

1;


