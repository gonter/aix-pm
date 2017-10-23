# $Id: LVM.pm,v 1.2 2012/04/23 00:05:32 gonter Exp $

use strict;

use AIX::LVM::tools;
use AIX::VPD::lscfg;
use Util::Simple_CSV;

package AIX::LVM;

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj= { 'lscfg_processed' => 0 }, $class;

  bless $obj;

  foreach my $par (keys %par)
  {
    if ($par eq 'init_lscfg' && $par{'init_lscfg'})
    {
      $obj->{'lscfg'}= new AIX::VPD::lscfg;
    }
  }

  $obj;
}

sub get_vg_survey
{
  my $obj= shift;
  $obj->{'VG'}= AIX::LVM::tools::get_vg_survey ();
}

sub get_pp_survey
{
  my $obj= shift;
  $obj->{'PP'}= AIX::LVM::tools::get_pp_survey ();
}

sub get_netapp_lun_info
{
  my $obj= shift;
  my $csv_file= shift || '/etc/my-netapp-luns.csv';

  my $csv= new Util::Simple_CSV;
  $csv->load_csv_file ($csv_file);
  my ($cnt, $idx)= $csv->index ('sernr');

  # print "netapp_lun_info: $cnt items found [", join (',', keys %$idx), "]\n";
  # print __FILE__, ' ', __LINE__, " idx_sernr=[$idx_sernr]: ", main::Dumper ($idx);
  $obj->{'netapp_lun_sernr'}= $idx;

  $obj->{'netapp_lun_info'}= $csv;
}

sub show_vg_survey
{
  my $obj= shift;

  foreach my $vg (sort keys %{$obj->{'VG'}})
  {
    $obj->show_vg_pv ($vg);
  }

  open (FO, '>@vgss.vg_survey.vgdump') or return;
  print FO __LINE__, ' LVM obj: ', Data::Dumper::Dumper ($obj);
  close (FO);
}

sub show_vg_pv
{
  my $obj= shift;
  my $vg= shift;    # name of a particular Volume Group

  my ($VG, $pp, $lscfg)= map { $obj->{$_} } qw(VG PP lscfg);

  unless ($obj->{'lscfg_processed'})
  {
    $lscfg->read_lscfg ();
    $obj->{'lscfg_processed'}= 1;
  }

## print __FILE__, ' ', __LINE__, " VG='$VG': ", main::Dumper ($VG);
## print __FILE__, ' ', __LINE__, " pp='$pp': ", main::Dumper ($pp);
## print __FILE__, ' ', __LINE__, " lscfg='$lscfg': ", main::Dumper ($lscfg);

  my $hdp_pvs= $VG->{$vg}->{'hdp'};  # PowerPath devices
## print __FILE__, ' ', __LINE__, " hdp_pvs='$hdp_pvs': ", main::Dumper ($hdp_pvs);
  my $hd_pvs= $VG->{$vg}->{'hd'};    # other hdisks
## print __FILE__, ' ', __LINE__, " hd_pvs='$hd_pvs': ", main::Dumper ($hd_pvs);
  my $pp_hds= $pp->{'hdisk'};  # list of hdisks which actually belong to PowerPath devices
## print __FILE__, ' ', __LINE__, " pp_hds='$pp_hds': ", main::Dumper ($pp_hds);

  my %pv_ss= ();
  my %ss_hdp= ();

# NOTE: this is PowerPath specific and should be handled via plugin
  if (defined ($hdp_pvs))
  {
# print __FILE__, ' ', __LINE__, " hdp_pvs=[$hdp_pvs]: ", main::Dumper ($hdp_pvs);
    my @hdp_pvs= sort { $a <=> $b } keys %$hdp_pvs;
    foreach my $hdp (@hdp_pvs)
    {
# print __LINE__, " hdp=[$hdp]\n";
      my $pv= $hdp_pvs->{$hdp};
# print __LINE__, " pv='$pv'\n"; # main::Dumper($pv), "\n";

      my $pp_dev= $pp->get_device ($pv);
      my ($clar_id, $lun_name)= $pp_dev->get ('CLARiiON ID', 'lun_name');
## print __LINE__, " pp_dev='$pp_dev'\n";
## print main::Dumper ($pp_dev);

      printf ("%-14s %-14s %-14s %s\n", $vg, $pv, $clar_id, $lun_name);
      $pv_ss{$pv}= $clar_id;
      push (@{$ss_hdp{$clar_id}}, $hdp);
    }
  }

  if (defined ($hd_pvs))
  {
    my $cfgdev= (defined ($lscfg) && exists ($lscfg->{'cfg'}->{'DEV'})) ? $lscfg->{'cfg'}->{'DEV'} : undef;
    my $netapp_lun_sernr;

    unless (defined ($netapp_lun_sernr= $obj->{'netapp_lun_sernr'}))
    {
      $obj->get_netapp_lun_info ();
      $netapp_lun_sernr= $obj->{'netapp_lun_sernr'};
    }

## print __FILE__, ' ', __LINE__, " hd_pvs=[$hd_pvs]: ", main::Dumper ($hd_pvs);
    my @hd_pvs= sort { $a <=> $b } keys %$hd_pvs;
    foreach my $hd (@hd_pvs)
    {
      my $pv= $hd_pvs->{$hd};

      # skip this hdisk, if it belongs to a PowerPath device; this
      # should only happen for hdisk in the dummy volume group 'None'
      next if (exists ($pp_hds->{$pv}));

      my $lun_comment= 'unknown';

      if (exists ($cfgdev->{$pv}))
      {
	my $dev= $cfgdev->{$pv};
	my $manufacturer= $dev->{'Manufacturer'};

        ## print "dev= ", main::Dumper ($dev);
	if ($manufacturer eq 'NETAPP')
	{
	  my $sernr= $dev->{'Serial Number'};
          if (exists ($netapp_lun_sernr->{$sernr}))
	  {
	    my $lun_info= $netapp_lun_sernr->{$sernr};
            # print "lun_info= ", main::Dumper ($lun_info); returns an array of hashes
            my ($ctrl, $vol_name, $lun_name)= map { $lun_info->[0]->{$_} } qw(ctrl vol_name lun_name);
	    $lun_comment= join (' ', $manufacturer, $ctrl, $sernr, $vol_name, $lun_name);
	  }
	  else
	  {
	    $lun_comment= "no lun info found manufacturer=[$manufacturer] sernr=[$sernr]";
	  }
	}
	elsif ($manufacturer eq 'DGC')
	{
	  my ($mtm, $sn, $ssv_devid)= map { $dev->{$_} } ('Machine Type and Model', 'Serial Number', 'Subsystem Vendor/Device ID');
	  $lun_comment= join (' ', $manufacturer, $mtm, $sn, $ssv_devid);
	}
	elsif ($manufacturer eq 'IBM   H0' || $manufacturer eq 'IBM')
	{
	  my ($mtm, $sn, $fru)= map { $dev->{$_} } ('Machine Type and Model', 'Serial Number', 'FRU Number');
	  $lun_comment= join (' ', $manufacturer, $mtm, $fru, $sn);
	}
	elsif ($manufacturer eq 'SUN')
	{
	  my ($mtm, $sn, $fru)= map { $dev->{$_} } ('Machine Type and Model', 'Serial Number'); # no id if the sn really means anything
	  $lun_comment= join (' ', $manufacturer, $mtm, $sn);
	}
	else
	{
	  $lun_comment= "unknown manufacturer=[$manufacturer]";
	}
      }

# TODO: identify NetApp Device via plugin here
      my $ss_sernr= 'no-id-00999';
## print __FILE__, ' ', __LINE__, " pv='$pv'\n"; # main::Dumper($pv), "\n";

      printf ("%-14s %-14s %-14s %s\n", $vg, $pv, $ss_sernr, $lun_comment);
      $pv_ss{$pv}= $ss_sernr;
      push (@{$ss_hdp{$ss_sernr}}, $hd);
    }
  }

    print "\n";

  my @pvs2= map { sort { $a <=> $b } @{$ss_hdp{$_}} } sort keys %ss_hdp;

  \%pv_ss, \@pvs2;
}

1;
