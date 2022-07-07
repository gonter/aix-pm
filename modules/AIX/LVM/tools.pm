# $Id: tools.pm,v 1.4 2012/04/22 20:02:57 gonter Exp $

use strict;

package AIX::LVM::tools;

use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
use Exporter;

use EMC::PowerPath;
use AIX::VPD::lscfg;

$VERSION= '0.01';
@ISA= qw(Exporter);
@EXPORT_OK= qw(sprint_pv_summary get_vg_survey get_pp_survey);
%EXPORT_TAGS= ('ALL' => \@EXPORT_OK);

# NOTE: maybe this should be moved to AIX::LVM::vg or be converted into a closure
sub sprint_pv_summary
{
  my $vg= shift;
  my $pvs= shift;
  my $hdp_hdpn= shift;

  my $what= shift;
  my $label= shift;

## print __FILE__, ' ', __LINE__, " what=[$what] pvs=[$pvs]: ", main::Dumper ($pvs);
## print __FILE__, ' ', __LINE__, " what=[$what] hdp_hdpn=[$hdp_hdpn]: ", main::Dumper ($hdp_hdpn);
## print __FILE__, ' ', __LINE__, " what=[$what] vg=[$vg]: ", main::Dumper ($vg);
  my $pv_sum= $vg->{$what};
## print __FILE__, ' ', __LINE__, " pv_sum='$pv_sum': ", main::Dumper ($pv_sum);
  my $res= sprintf ("        %-16s", $label);

  foreach my $hdp (@$pvs)
  {
    my $hdpn= $hdp_hdpn->{$hdp};
## print __FILE__, ' ', __LINE__, " hdp=[$hdp] hdpn: ", main::Dumper ($hdpn);
    # printf (" %6s", $hdpn);
    $res .= sprintf (" %6d", $pv_sum->{$hdpn});
  }

## print __FILE__, ' ', __LINE__, " what=[$what] res='$res': ", main::Dumper ($res);
  $res;
}

sub get_vg_survey
{
  my @lspv= split ("\n", `/usr/sbin/lspv`);

  my $VG;
  foreach (@lspv)
  {
    my ($pv, $pv_id, $vg)= split (' ');
    if ($pv =~ m#^hdiskpower(\d+)$#)
    {
      my $hdp= $1;
      $VG->{$vg}->{'hdp'}->{$hdp}= $pv;
    }
    elsif ($pv =~ m#^hdisk(\d+)$#)
    {
      my $hd= $1;
      $VG->{$vg}->{'hd'}->{$hd}= $pv;
    }
  }

  ## print "VG: ", Dumper ($VG), "\n";
  $VG;
}

sub get_pp_survey
{
  my $pp= new EMC::PowerPath;
  $pp->parse ('all');

  ## print "PP: ", Dumper ($pp), "\n";
  $pp;
}

__END__
