#
# $Id: SPPort.pm,v 1.4 2010/03/16 18:03:38 gonter Exp $
#

use strict;

package EMC::Config::Port::SPPort;

my %port_diag=
(
  'Link Status' => { 'policy' => 'link_status', 'expected' => 'Up', },
  'Port Status' => { 'policy' => 'port_status', 'expected' => 'Online' },
);

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;
  $obj->set (@_);

  $obj;
}

sub set
{
  my $obj= shift;
  my %par= @_;
  foreach my $par (keys %par)
  {
    $obj->{$par}= $par{$par};
  }
}

sub print_csv_header
{
  local *FO= shift;

  my $CSV_SEP= shift || ';';
  print FO join ($CSV_SEP, qw(san controller spport fabric zoning alias sp port
                 ty uid ps ls sw_pr sw_uid ri lii nlii)), "\n";

}

sub print_as_csv
{
  my $p_obj= shift;
  local *FO= shift;
  my $san= shift;
  my $CSV_SEP= shift || ';';

  return 0 unless $p_obj;

  my ($controller, $spport, $fabric, $zoning, $alias, $sp_name, $p_id, $p_uid,
      $ps, $ls, $sw_pr, $sw_uid, $ri, $lii, $nlii, $spport_type)=
         map { $p_obj->{$_} }
	 ( 'controller', 'spport', 'fabric', 'zoning', 'alias',
           'SP Name', 'SP Port ID', 'SP UID', 'Port Status',
	   'Link Status', 'Switch Present', 'Switch UID',
	   'Registered Initiators', 'Logged-In Initiators', 'Not Logged-In Initiators',
           'spport_type',
	 );

  print FO join ($CSV_SEP, $san, $controller, $spport, $fabric, $zoning, $alias,
		 $sp_name, $p_id, $spport_type, $p_uid, $ps, $ls,
		 $sw_pr, $sw_uid, $ri, $lii, $nlii), "\n";

  1;
}

1;
