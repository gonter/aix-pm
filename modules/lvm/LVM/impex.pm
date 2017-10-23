# $Id: impex.pm,v 1.4 2010/10/22 23:05:17 gonter Exp $

use strict;

package AIX::LVM::impex;

use EMC::PowerPath;
use AIX::NIM::Config;
use AIX::LVM::vg;
use AIX::LVM::tools (':ALL');

use Data::Dumper;
$Data::Dumper::Indent= 1;

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->reset ();
  $obj->set (@_);

  $obj;
}

sub reset
{
  my $obj= shift;

  $obj->{'cmd_export'}= [];
  $obj->{'cmd_import'}= [];
  $obj->{'cmd_umount'}= [];
  $obj->{'cmd_mount'}= [];
  $obj->{'cmd_removehlu'}= [];
  $obj->{'cmd_vg_reimport'}= [];
  $obj->{'sg_parking'}= '_RECYCLE_';
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

sub vg_lv_export
{
  my $obj= shift;
  my $vg_name= shift;

  my $vg= new AIX::LVM::vg ('vg_name' => $vg_name);
  my @pv_names= $vg->get_pv_names ();
  my @lv_names= $vg->get_lv_names ();
  $obj->{'vg_name'}= $vg_name;
  $obj->{'_vg_'}= $vg;
  $obj->{'pv_names'}= \@pv_names;

  # print 'vg: ', Dumper ($vg), "\n";
  # print 'pv_info: ', Dumper (\@pv_names), "\n";
  # print 'lv_info: ', Dumper (\@lv_names), "\n";

  my $cmd_umount= $obj->{'cmd_umount'};
  my $cmd_mount=  $obj->{'cmd_mount'};
  foreach my $lv_name (@lv_names)
  {
    my $lv= $vg->get_lv ($lv_name);
    # print "lv $lv_name: ", Dumper ($lv), "\n";
    my ($ty, $state, $mount_point)= $lv->get ('TYPE', 'LV STATE', 'MOUNT POINT');
    # printf ("# %s %s %s %s\n", $lv_name, $ty, $state, $mount_point);

    next if ($ty eq 'jfslog' || $ty eq 'jfs2log');
    next if ($state eq 'closed/synced');

    push (@$cmd_umount, "umount '$mount_point' # $lv_name");
    push (@$cmd_mount,  "mount  '$mount_point' # $lv_name");
  }

  (wantarray) ? @pv_names : \@pv_names;
}

sub pv_export_check
{
  my $obj= shift;
  my @pv_names= @_;
## print join (' ', __FILE__, __LINE__, 'pv_export_check', @pv_names), "\n";

  my @cmds= ();
  my %ss_sernr;
  $obj->{'ss_sernr'}= \%ss_sernr;

  my $rmdev_opt= $obj->{'rmdev_opt'} || '-dl';
  my $cmd_export= $obj->{'cmd_export'};
  my $cmd_import= $obj->{'cmd_import'};
  my $sg_parking= $obj->{'sg_parking'};
  my $cmd_removehlu= $obj->{'cmd_removehlu'};

  foreach my $pv_name (@pv_names)
  {
    ## not used! my $pv= $vg->get_pv ($pv_name);
    ## print "pv $pv_name: ", Dumper ($pv), "\n";

    if ($pv_name =~ /hdiskpower\d+/)
    {
      my $pp= new EMC::PowerPath;
      $pp->parse ($pv_name);
      ## print "powerpath $pv_name: ", Dumper ($pp), "\n";

      foreach my $pp_dev (@{$pp->{'device_list'}})
      {
	my ($paths, $sg_name, $ss, $uid, $pseudo, $lun_name)= $pp_dev->get ('paths', 'SG_name', 'CLARiiON ID', 'logical_dev_id', 'Pseudo name', 'lun_name');
        my $cmd_hdp= "rmdev $rmdev_opt '$pv_name'";
        # print $cmd_hdp, "\n";

        my @cmds_hdisk;
	push (@{$ss_sernr{$ss}}, [$ss, $sg_name, $uid, $pseudo, $lun_name, $cmd_hdp, \@cmds_hdisk]);
	push (@$cmd_removehlu, "./sawhois.pl --silent -uid '$uid' -rem -park $sg_parking");

        foreach my $path (@$paths)
        {
	  my $hdisk= $path->[2];
	  my $cmd_hdisk= "rmdev $rmdev_opt '$hdisk'";
          push (@cmds_hdisk, $cmd_hdisk);
        }
      }
    }
  }

## print 'ss_sernr: ', Dumper (\%ss_sernr), "\n";

  \%ss_sernr;
}

sub do_pv_export
{
  my $obj= shift;
  local *FO= shift;

  my $ss_hash= $obj->{'ss_sernr'};

  my @uids;
  foreach my $ss_sernr (keys %$ss_hash)
  {
    foreach my $ss_info (@{$ss_hash->{$ss_sernr}})
    {
      my ($ss, $sg_name, $uid, $pseudo, $lun_name, $cmd_hdp, $cmds_hdisk)= @$ss_info;
      push (@uids, $uid);

      print FO $cmd_hdp, "\n";
      &do_cmd_list (*FO, $cmds_hdisk);

      # print "# request removehlu uid='$uid' from ss='$ss' sg='$sg_name' lun_name='$lun_name'\n";
    }
  }

  my $cmd= "$0 -imp " . join (' ', '-vg', $obj->{'vg_name'}, '-uids', @uids);
  push (@{$obj->{'cmd_vg_reimport'}}, $cmd);
  # print "# request import: $cmd\n";
}

sub do_cmd_list
{
  local *FO= shift;
  my $cmd_list= shift;

  foreach my $cmd (@$cmd_list)
  {
    print FO $cmd, "\n";
  }
}

sub pv_import
{
  my $obj= shift;
  my $vg_name= shift;
  my $doit= shift;
  my @uids_wanted= @_;
  
  my $rc= -1;
  my %uids_wanted= map { $_ => undef } @uids_wanted;

  $obj->{'_VG_'}= my $VG= get_vg_survey ();
  # $obj->{'_PP_'}= my $PP= get_pp_survey ();

  my %PV_PP; $obj->{'_PV_PP_'}= \%PV_PP;

  ## print join (' ', __LINE__, keys %$VG), "\n";

  my @pv_nums= keys %{$VG->{'None'}};
  push (@pv_nums, keys %{$VG->{'share99'}}); # for testing ...
  ## print join (' ', __LINE__, @pv_nums), "\n";

  my @pv_names_found= ();
  my @uids_not_used= ();
  foreach my $pv_num (@pv_nums)
  {
    my $pv_name= 'hdiskpower' . $pv_num;
    print "pv_num: '$pv_num' pv_name='$pv_name'\n";
    my $pp= new EMC::PowerPath;
    $pp->parse ($pv_name);
    $PV_PP{$pv_name}= $pp;

    foreach my $dev (@{$pp->{'device_list'}})
    {
      my ($sernr, $uid_seen, $sg_name, $lun_name)= map { $dev->{$_} } ('CLARiiON ID', 'logical_dev_id', 'SG_name', 'lun_name');
      my $rec= [ $pv_name, $sernr, $uid_seen, $sg_name, $lun_name ];

      if (exists ($uids_wanted{$uid_seen}))
      {
        $uids_wanted{$uid_seen}= $rec;
	push (@pv_names_found, $rec);
      }
      else
      {
	push (@uids_not_used, $rec);
      }
    }
  }

  my @missing= ();
  print "LUNs for vg '$vg_name' found:\n";
  foreach my $uid (keys %uids_wanted)
  {
# ZZZ
    my $rec= $uids_wanted{$uid};
## print "rec: ", Dumper ($rec), "\n";

    unless (defined ($rec))
    {
      push (@missing, $uid);
      $rec= [ '<missing>' ];
    }

    print join (' ', @$rec), "\n";
  }

  if (@missing)
  {
    print "can not import VG '$vg_name', there are missing LUNs: ", join (', ', @missing), "\n";
    $rc= 1;
  }
  else
  {
    my $cmd= "importvg -y '$vg_name' ". $pv_names_found[0]->[0];
    print ">>> [$cmd]\n";
    my $rc= system ($cmd) if ($doit);
    print ">>>> rc='$rc'\n";
    $rc= 0;
  }

  if (@uids_not_used)
  {
    print "LUNs which are not used:\n";
    foreach my $rec (@uids_not_used)
    {
      print join (' ', @$rec), "\n";
    }
  }

  # print 'obj: ', Dumper ($obj), "\n";
}

1;

__END__

TODO:
* Daten fuer den Import auf dem Ziel-Host vorbereiten, z.B. dass anhand
  der UID einer der PVs der VG Name fuer die neue VG vorgeschlagen wird.


