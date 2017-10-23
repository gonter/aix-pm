# $Id: AIX.pm,v 1.2 2012/04/22 13:30:37 gonter Exp $

package SAN::Policy::AIX;

# Note: this is very specfic to EMC storage and AIX as operating system :-/

use Data::Dumper;
use AIX::NIM::Config;
use AIX::VPD::lscfg;

sub new
{
  my $class= shift;

  my $X=
  {
    'zones' => [],
    'file_loaded' => {},
  };

  bless $X, $class;
}

# A policy reload is needed if there was no policy load yet
# or if any of the loaded file was modfied after the first
# loaded file was loaded.
sub need_policy_reload
{
  my $X= shift;

  my $first= $X->{'first_file_loaded'};
## print __LINE__, " >> first='$first'\n";
  return 1 unless (defined ($first));

  my $fl= $X->{'file_loaded'};
## print __LINE__, " >> fl='$fl'\n";
  foreach my $fnm (keys %$fl)
  {
## print __LINE__, " >> fnm='$fnm'\n";
    my $f_mtime= $fl->{$fnm};
## print __LINE__, " >> f_mtime='$f_mtime'\n";
    my @f_stat= stat ($fnm);
    return 1 unless (defined (@f_stat)); # file removed?? reload!

## print __LINE__, " >> f_stat[9]='$f_stat[9]'\n";
    return 1 if ($f_stat[9] > $first);   # file modified after policy load
  }

  return 0; # no changes
}

sub load_policy
{
  my $X= shift;
  my $fnm= shift;

  my $pol= new AIX::NIM::Config;
  print "SAN::Policy::AIX::load_policy reading config file '$fnm'\n";
  $pol->get_config ($fnm);
  ## print "read config file '$fnm'\n";

  my $now= time ();
  $X->{'file_loaded'}->{$fnm}= $now;
  $X->{'first_file_loaded'}= $now unless (defined ($X->{'first_file_loaded'}));

  my $cfg= $pol->get_object ('cfg');
  if (defined ($cfg))
  {
    ## print "cfg: ", Dumper ($cfg), "\n";

    my @additional_config= $cfg->av ('cfg');
## print "additional_config: [", join (',', @additional_config), "]\n";
## print Dumper (\@additional_config);
    foreach my $additional_config (@additional_config)
    {
      &load_policy ($X, $additional_config) if (defined ($additional_config));
    }

    my @zone_files= $cfg->av ('zones');
## print "zone_files: [", join (',', @zone_files), "]\n";
    if (@zone_files)
    {
      map { $X->load_zone_info_file ($_); } @zone_files;
    }
    else
    {
      print "ATTN: no zones in cfg-object\n";
    }
    ## print __FILE__, ' ', __LINE__, ' X: ', Dumper ($X), "\n";
  }

  # old format of SP-port data, used only on fs1
  my @sp_ports_old= $pol->select_objects ('class' => 'cfg', 'type' => 'sp_port');
  ## print "sp_ports: ", Dumper (\@sp_ports), "\n";
  foreach my $sp_port (@sp_ports_old)
  {
    &load_sp_port_info_old ($X, $sp_port);
  }

  # new format of SP-port data
  my @sp_ports_new= $pol->select_objects ('class' => 'policy', 'type' => 'spport');
  foreach my $sp_port (@sp_ports_new)
  {
    &load_sp_port_info ($X, $sp_port);
  }

  my @sans= $pol->select_objects ('class' => 'policy', 'type' => 'san');
  ## print "sans: ", Dumper (\@sans), "\n";
  foreach my $san (@sans)
  {
    &load_san_info ($X, $san);
  }

  my @event_logs= $pol->select_objects ('class' => 'policy', 'type' => 'event_log');
  &load_event_log ($X, $event_logs[0]);
}

sub load_event_log
{
  my $X= shift;
  my $event_log= shift;

  return unless (defined ($event_log));
  delete ($event_log->{'_'});

  print "event_log stanza: ", Dumper ($event_log);
  my %el= map { $_ => $event_log->{$_}; } qw(url who);

  $X->{'event_log'}= \%el;
}

sub load_zone_info_file
{
  my $X= shift;
  my $fnm= shift;

  print "SAN::Policy::AIX::load_zone_info_file fnm=[$fnm]\n";
  my $pol= new AIX::NIM::Config;
  $pol->get_config ($fnm);
  # print __FILE__, ' ', __LINE__, " X: ", Dumper ($X), "\n";
  # print __FILE__, ' ', __LINE__, " pol: ", Dumper ($pol), "\n";

  # my @zones= $pol->select_objects ('class' => 'policy', 'type' => 'cfg');
  my @zones= $pol->select_objects ('class' => 'cfg', 'type' => 'zone');
  # print __FILE__, ' ', __LINE__, " zones: ", Dumper (\@zones), "\n";
  foreach my $zone (@zones)
  {
    &load_zone_info ($X, $zone);
  }

}

# check if a given zone from a file that represents the global information
# matches one of my own WWNs; only such a zone is of interest to us.
sub load_zone_info
{
  my $X= shift;
  my $data= shift;

# print __LINE__, " data: ", Dumper ($data), "\n";
  my $x;
  map { $x->{$_}= $data->{$_} } qw(fabric name);

  my $wwns= $data->{'wwn'};
  my $my_wwns= $X->{'my_wwns'};
# print __LINE__, " my_wwns: ", Dumper ($my_wwns), "\n";

  my @other_wwns= (); # list of other wwns
## print __LINE__, " wwns: ", Dumper ($wwns), "\n";
  if (ref ($wwns) eq 'ARRAY')
  {
    foreach my $wwn (@$wwns)
    {
      if (exists ($my_wwns->{$wwn}))
      {
# print __LINE__, " match wwn='$wwn'\n";
        push (@{$X->{zones}}, $x);
        $x->{'my_wwn'}= $wwn;
        $x->{'other_wwns'}= \@other_wwns
      }
      else
      {
        push (@other_wwns, $wwn);
      }
    }
  }
  else
  {
## print __LINE__, " zone with one alias? data: ", Dumper ($data), "\n";
  }
}

=pod

=head2 $X->load_sp_port_info (data);

record data about storage processor ports

=cut

sub load_sp_port_info_old
{
  my $X= shift;
  my $data= shift;

## print __LINE__, " data: ", Dumper ($data), "\n";
  # extract information about a SP port from data record
  my $x;
  map { $x->{$_}= $data->{$_} } qw(sernr wwn fabric sp port);
  $x->{'reachable'}= undef; # later we check available zones and mark reachable ports with 1

  $X->{'SP_ports'}->{$x->{'wwn'}}= $x;
}

sub load_sp_port_info
{
  my $X= shift;
  my $data= shift;

  # extract information about a SP port from data record
  my $x;
  map { $x->{$_}= $data->{$_} } qw(sernr wwpn wwnn fabric sp port zoning);
  $x->{'wwn'}= $x->{$x->{'zoning'}}; # this wwn is used

  $X->{'SP_ports'}->{$x->{'wwn'}}= $x;
}

sub load_san_info
{
  my $X= shift;
  my $data= shift;

## print __LINE__, " data: ", Dumper ($data), "\n";
  my $x;
  map { $x->{$_}= $data->{$_} } qw(short_name system model sernr);

  $X->{'san'}->{$x->{'sernr'}}= $x;
}

=pod

=head2 $X->match_zones ();

Compare WWNs in zones that are relevant for us and find out which
storage system port we can see.

=cut

sub match_zones
{
  my $X= shift;

  my $zones= $X->{'zones'};
# print __LINE__, " >>> zones=[$zones] ", Dumper ($zones);
  return undef unless (defined ($zones) && ref ($zones) eq 'ARRAY');

  my $SP_ports= $X->{'SP_ports'};
# print __LINE__, " >>> SP_ports=[$SP_ports] ", Dumper ($SP_ports);
  return undef unless (defined ($SP_ports) && ref ($SP_ports) eq 'HASH');

  my $my_wwns= $X->{'my_wwns'};
# print __LINE__, " >>> my_wwns=[$my_wwns] ", Dumper ($my_wwns);
  return undef unless (defined ($my_wwns) && ref ($my_wwns) eq 'HASH');

  my $sans= $X->{'san'};
# print __LINE__, " >>> sans='$sans': ", main::Dumper ($sans);
  return undef unless (defined ($sans) && ref ($sans) eq 'HASH');

  # step 1: find those SP ports that known zoning allows us to see
  my ($cnt_reachable, $cnt_unknown)= (0, 0);
  foreach my $zone (@$zones)
  {

    # print __LINE__, " zone: ", Dumper ($zone);

    my ($zone_name, $my_wwn, $other_wwns, $fabric)= map { $zone->{$_} } qw(name my_wwn other_wwns fabric);

    foreach my $other_wwn (@$other_wwns)
    {
      my $sp_port;

# print "other_wwn=[$other_wwn]\n";
      if (defined ($sp_port= $SP_ports->{$other_wwn}))
      {
# print "match!\n";
        $sp_port->{'reachable'}= [] unless (defined ($sp_port->{'reachable'}));
        push (@{$sp_port->{'reachable'}}, $my_wwns->{$my_wwn});
	$cnt_reachable++;

        # check if fabric information matches; this my be the result of wrong config data
	if ($sp_port->{'fabric'} ne $fabric)
	{
	  print "WARNING: fabric information does not match!\n";
	  print "zone: ", Dumper ($zone), "\n";
	  print "sp_port: ", Dumper ($sp_port), "\n";
	}

      }
      else
      {
	print "WARNING: unknown SP port '$other_wwn' in zone '$zone_name' fabric='$fabric'\n";
        $sp_port= $SP_ports->{$other_wwn}= { 'wwn' => $other_wwn, 'state' => 'unknown' };
	$cnt_unknown++;
      }
    }
  }

# print __LINE__, " >>> SP_ports=[$SP_ports] ", Dumper ($SP_ports);
  # step 2: 
  foreach my $sp_port (keys %$SP_ports)
  {
    my $x= $SP_ports->{$sp_port};
    my ($sernr, $sp, $port, $reachable, $fabric)= map { $x->{$_} } qw(sernr sp port reachable fabric);

    my $san= $sans->{$sernr};
    unless (defined ($san))
    {
      print "WARNING: SAN sernr='$sernr' not defined in policy file!\n";
      $X->{'san'}->{$sernr}= $san= { 'sernr' => $sernr, 'system' => 'unknown' , 'model' => 'unknown' };
    }

    next unless (defined ($reachable)); # we do not care for SP ports which are not visible for us
    foreach my $fscsi (@$reachable)
    {
      my $y= [ $fscsi,
               join ('', 'SP ', $sp, $port), # this format is specific for EMC PowerPath
               $fabric
              ];
      push (@{$san->{'paths'}}, $y);
    }
  }

  ($cnt_reachable, $cnt_unknown);
}

=pod

=head2 $X->get_fcs ();

find out which fcs adapters and fscsi devices are present and record their WWNs

Note: this is purely AIX related

=cut

sub get_fcs
{
  my $X= shift;

  my $cfg= new AIX::VPD::lscfg;
  $cfg->read_lscfg ();

  my $my_wwns= $X->{'my_wwns'};
  unless (defined ($my_wwns))
  {
    $X->{'my_wwns'}= $my_wwns= {};
  }

  my ($fscsi)= $cfg->get ('fscsi');
## print Dumper ($fscsi), "\n";
  foreach my $dn_fscsi (@$fscsi)
  {
    my ($d_fscsi)= $cfg->device ($dn_fscsi);
    my $dn_fcs= $d_fscsi->{'fcs'};
    my ($d_fcs)= $cfg->device ($dn_fcs);
    my $wwpn= $d_fcs->WWPN ();
    my $wwnn= $d_fcs->WWNN ();

    ## print __LINE__, " dn_fscsi='$dn_fscsi' dn_fcs='$dn_fcs' wwnn='$wwnn' wwpn='$wwpn'\n";
    ## d_fscsi='$d_fscsi'

    my $x=
    {
      'fscsi' => $dn_fscsi,
      'fcs'   => $dn_fcs,
      'wwnn'  => $wwnn,
      'wwpn'  => $wwpn,
    };

    $my_wwns->{$wwnn}= $dn_fscsi;
    $my_wwns->{$wwpn}= $dn_fscsi;

    $X->{'fcs'}->{$dn_fcs}= $dn_fscsi;
    $X->{'fscsi'}->{$dn_fscsi}= $x;
  }
}

1;

__END__

