#
# $Id: HBA.pm,v 1.4 2010/03/16 18:03:38 gonter Exp $
#

use strict;

package EMC::Config::Port::HBA;

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
  print FO join ($CSV_SEP, qw(san sp port hba ip name ArrayCommPath Failover_mode SG Defined Logged_In)), "\n";
}

sub print_as_csv
{
  my $p_obj= shift;
  local *FO= shift;
  my $san= shift;
  my $CSV_SEP= shift || ';';

  return 0 unless $p_obj;

  my ($hba_uid, $srv_ip, $srv_name, $SP)=
         map { $p_obj->{$_} }
	 ( 'HBA UID', 'Server IP Address', 'Server Name', 'SP');

  my $lines= 0;
  foreach my $sp (sort keys %$SP)
  {
    my $spx= $SP->{$sp};
    foreach my $port_id (sort keys %{$spx->{'port'}})
    {
      my $px= $spx->{'port'}->{$port_id};
      my ($ArrayCommPath, $Failover_mode, $SG, $def, $li)= map { $px->{$_}; } ('ArrayCommPath', 'Failover mode', 'StorageGroup Name', 'Defined', 'Logged In');

      print FO join ($CSV_SEP, $san, $sp, $port_id, $hba_uid, $srv_ip, $srv_name, $ArrayCommPath, $Failover_mode, $SG, $def, $li), "\n";
      $lines++;
    }
  }

  $lines;
}

sub print_hba_port_info
{
  my $obj= shift;

  my ($ip, $name, $HBA_UID, $SP)= map { $obj->{$_}; } ('Server IP Address', 'Server Name', 'HBA UID', 'SP');

  my (%ArrayCommPath, %Failover_mode, %SG);
  foreach my $sp (keys %$SP)
  {
    my $spx= $SP->{$sp};
    foreach my $port_id (keys %{$spx->{'port'}})
    {
      my $px= $spx->{'port'}->{$port_id};
      my ($ArrayCommPath, $Failover_mode, $SG)= map { $px->{$_}; } ('ArrayCommPath', 'Failover mode', 'StorageGroup Name');

      ## print __LINE__, " $name: $sp $port Failover_mode=$Failover_mode\n";

      $ArrayCommPath{$ArrayCommPath}++;
      $Failover_mode{$Failover_mode}++;
      $SG{$SG}++;
    }
  }

  my @ArrayCommPath= keys %ArrayCommPath;
  my @Failover_mode= keys %Failover_mode;
  my @SG= keys %SG;

  print "ATTN: " if (@Failover_mode > 1 || @ArrayCommPath > 1);

  printf ("%-15s %-30s %48s ", $ip, $name, $HBA_UID);
  print join (' ', 'Failover_mode:', @Failover_mode, 'ArrayCommPath:', @ArrayCommPath, 'SG:', @SG);
  print "\n";
}

1;
