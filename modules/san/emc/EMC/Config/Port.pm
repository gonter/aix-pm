#
# $Id: Port.pm,v 1.8 2012/01/26 17:19:16 gonter Exp $
#

use strict;

package EMC::Config::Port;

use strict;
use Data::Dumper;

use EMC::Config::Port::HBA;
use EMC::Config::Port::SPPort;

=pod

=head1 NAME

EMC::Config::Port  --  EMC Port configuraton

=cut

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj=
  {
    'SP' => {},       # list of storage processes, typically 'SP A' and 'SP B'
    'wwpn' => {},     # list of WWPN of front-end ports
    'HBA_list' => [], # list of connected/registered HBAs
  };

  bless $obj, $class;
  foreach my $par (keys %par) { $obj->{$par}= $par{$par}; }
  $obj;
}

# This method is called for items in the first and in the last section of the port command output.
# It is also called for the SP port specific items of HBAs
sub analyze_sp_port
{
  my $obj= shift;
  my $item= shift;
## print __FILE__, ' ', __LINE__, " >> item='$item'\n";

  my %f= ();
  my @l= @$item;
  foreach my $l (@l)
  {
    ## print __FILE__, ' ', __LINE__, " >> l='$l'\n";
    $f{$1}= $2 if ($l =~ /\s*(\S[^:]*):\s+(.+)/);
  }

  my ($sp_name, $sp_port, $p_uid, $switch_present, $switch_uid)=
     map { $f{$_} } ('SP Name', 'SP Port ID', 'SP UID', 'Switch Present', 'Switch UID');

  unless (defined ($sp_name) && defined ($sp_port))
  {
    print "no SP name and port id found $l[0] $l[1]\n";
    return undef;
  }

  my $po;
  unless (defined ($po= $obj->{'SP'}->{$sp_name}->{'port'}->{$sp_port}))
  {
    $po= $obj->{'SP'}->{$sp_name}->{'port'}->{$sp_port}= new EMC::Config::Port::SPPort ();
  }

  # find out if this port is a FC or iSCSI port, normalize and cross reference it as necessary
  my $spport_type;
  if ($p_uid =~ /^[a-fA-F\d:]+$/)
  {
    $spport_type= 'FC';
    my ($uid, $wwnn, $wwpn)= &_split_FC_uid ($p_uid);
    $f{'SP UID'}= $uid;
    $f{'wwnn'}= $wwnn;
    $f{'wwpn'}= $wwpn;

    ## $obj->{'wwpn'}->{$wwpn}= $sp_port;
    $obj->{'wwpn'}->{$wwpn}= $po;
    $f{'spport_type'}= $spport_type;
  }
  elsif ($p_uid eq '') {} # NOP; this may be data for HBA
  else
  { # TODO: something maybe done here
    $spport_type= 'iSCSI';
    $f{'spport_type'}= $spport_type;
  }

  if ($switch_present eq 'YES')
  {
    my ($uid, $wwnn, $wwpn)= &_split_FC_uid ($switch_uid);
    $f{'Switch UID'}= $uid;
    $f{'switch_wwnn'}= $wwnn;
    $f{'switch_wwpn'}= $wwpn;
    $obj->{'Switch'}->{$wwnn}->{$wwpn}= $po; # let's see if this is useful
  }

  $po->set (%f);
## print __LINE__, ' ', Dumper ($po), "\n";

  $po;
}

sub analyze_hba
{
  my $obj= shift;
  my $item= shift;

  my %f= ();
  my @l= @$item;
  foreach my $l (@l)
  {
    ## print __FILE__, ' ', __LINE__, " >> l='$l'\n";
    next if (/Information about each port of this HBA/);
    $f{$1}= $2 if ($l =~ /(.+):\s+(.+)/);
  }

  my $hba_uid;
  if (defined ($hba_uid= $f{'HBA UID'}) && $hba_uid =~ /^[a-fA-F\d:]+$/)
  {
    my ($uid, $wwnn, $wwpn)= &_split_FC_uid ($hba_uid);
    $f{'HBA UID'}= $uid;
    $f{'wwnn'}= $wwnn;
    $f{'wwpn'}= $wwpn;
  }
  # TODO: else there is something wrong!

  my $hba_obj= new EMC::Config::Port::HBA (%f);
  push (@{$obj->{'HBA_list'}}, $hba_obj);

  $hba_obj;
}

sub _split_FC_uid
{
  my $uid= shift;

  $uid=~ tr/A-F/a-f/;
  my @uid= split (':', $uid);
  ($uid, join (':', @uid[0..7]), join (':', @uid[8..15]));
}

=pod

=head2 $obj->fixup_policy_port ($policy);

transcribe data from policy information into port object; also check for diagnostic
problems and missing policy data;

returns a bit coded status:
0x00 .. all is fine
0x01 .. diagnosic problems (e.g. link is down, should be up)
0x02 .. missing templates

=cut

sub fixup_policy_port
{
  my $port_obj= shift;
  my $policy_obj= shift;

  ## print 'Port: ', Dumper ($port_obj), "\n";
  ## print 'Policy: ', Dumper ($policy_obj), "\n";

  my $status= 0x00;
  my @main_diag= ();

  foreach my $wwpn (sort keys %{$port_obj->{'wwpn'}})
  {
# print __FILE__, ' ', __LINE__, ' policy_obj=[$policy_obj] ', main::Dumper ($policy_obj);
    my $wwpn_p= $port_obj->{'wwpn'}->{$wwpn};
    my $spport_p= $policy_obj->find_wwpn ($wwpn);
    my @diag= ();

    ## print "wwpn: '$wwpn'\n";
    ## print "wwpn_p vorher: ", Dumper ($wwpn_p), "\n";
    ## print "spport_p: ", Dumper ($spport_p), "\n\n";

    if (defined ($spport_p))
    {
      map { $wwpn_p->{$_}= $spport_p->{$_} } qw(controller fabric zoning spport alias);
      foreach my $n (sort keys %EMC::Config::Port::SPPort::port_diag)
      {
	my $d= $EMC::Config::Port::SPPort::port_diag{$n};
        my $pn= $d->{'policy'};
        my $expected= $spport_p->{$pn};
	my $currently= $wwpn_p->{$n};

	if ($currently ne $expected)
	{
	  push (@diag, "ATTN: '$n' currently '$currently', expected '$expected' ($pn)");
	  $status |= 0x01;
	}
      }
    }
    else
    {
      $status |= 0x02; # missing policy template
      my $wwnn= $wwpn_p->{'wwnn'};
      my $wwpnx= $wwpn; $wwpnx=~ s/://g;

      push (@diag, "missing policy template " . <<EOX);
%sanport_name%_eg_$wwpnx:
   class = policy
   type = spport
   controller = %CONTROLLER_NAME%
   spport_type = FC
   wwnn = $wwnn
   wwpn = $wwpn
   fabric = %FABRIC_NAME%
   zoning = wwpn
   wwpn_alias = %ALIAS_NAME%
   port_status = Online
   link_status = Up
EOX
    }

    if (@diag)
    {
      $wwpn_p->{'_diag_'}= \@diag;
      push (@main_diag, "diagnostics for SP Port ", join (' ', map { $wwpn_p->{$_} } ('SP Name', 'SP Port ID')), @diag);
    }

    ## print "wwpn_p nachher: ", Dumper ($wwpn_p), "\n";
  }
 
  return ($status, \@main_diag);
}

1;

__END__

