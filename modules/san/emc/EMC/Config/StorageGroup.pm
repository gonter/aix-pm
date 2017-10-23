#
# $Id: StorageGroup.pm,v 1.8 2010/04/26 15:57:56 gonter Exp $
#

=pod

=head1 NAME

EMC StorageGroup Configuration

=head1 SYNOPSIS

my $sg= new EMC::Config::StorageGroup ('SG name');

create new StorageGroup object with specified name

=cut

package EMC::Config::StorageGroup;

use strict;

sub new
{
  my $class= shift;
  my $sg_name= shift;

  my $do=
  {
    'storage_group' => $sg_name,
  };

  bless $do, $class;
  $do;
}

=cut

=head2 $sg->analyze ($item);

analyze a bunch of configuration lines ($item is a array reference)
  
=head2 $sg->segment ($what, $item);

analyze a bunch of configuration lines ($item is again a array
reference).  $what indicates the type of the configuration segment.

=cut

sub analyze
{
  my $cl_or_obj= shift;
  my $item= shift;

  # print __LINE__, " cl_or_obj='$cl_or_obj'\n";
  ## &main::print_refs (*STDOUT, 'item', $item);

  my $tag= $item->[0];
  my $obj_type= 'invalid';
  my $label;

  if ($tag =~ m#Storage Group Name:\s+(.+)#)
  {
    $label= $1;
    $obj_type= 'StorageGroup';
  }
  else { return ('invalid', $tag, $item); }

  my $do= new EMC::Config::StorageGroup ($label);
  $do->{'label'}= $do->{'Storage Group Name'}= $label;

  my @l= @$item;
  shift (@l);

  foreach my $l (@l)
  {
## print __LINE__, " >>>> $l\n";
    if ($l =~ m#^Storage Group UID:\s+([\da-fA-F:]+)#)
    {
      $do->{'Storage Group UID'}= $1;
## print __LINE__, " >>>>>>>>>>>>> $1\n";
    }
    elsif ($l =~ m#^Shareable:\s+(.+)#)
    {
      $do->{'Shareable'}= $1;
    }
    elsif ($l eq 'HBA/SP Pairs:') {}  # NOP, data follows as hba_uid segment
    elsif ($l =~ m#^\s*$#) {}         # empty lines
    else
    {
      print __LINE__, " unknown line: '$l'\n";
    }
  }

  ($obj_type, $label, $do);
}

sub segment
{
  my $obj= shift;
  my $what= shift;
  my $item= shift;
 
  ## &main::print_refs (*STDOUT, 'segment_item_' . $what, $item);

  if ($what eq 'hba_uid')
  {
    shift (@$item); # header line
    shift (@$item); # separator line
    while (@$item)
    {
      my $l1= shift (@$item);

      if ($l1 =~ m#^Shareable:\s+(.+)#)
      {
        $obj->{'Shareable'}= $1;
        next;
      }

      my $l2= shift (@$item);

      my ($hba, $sp, $port, $host);
      if ((($hba, $sp, $port)= ($l1 =~ m#^  ([\d[a-fA-F:]+)\s+(SP [A-Z])\s+(\d+)#))
	  && (($host)= ($l2 =~ m#^Host name:\s+(.+)#))
	 )
      {
	## print ">>> ", join ('|', $hba, $sp, $port, $host), "\n";
	my ($wwnn, $wwpn)= &split_wwn ($hba);

	push (@{$obj->{'hba'}},
	      {
	        'hba_wwnn' => $wwnn,
	        'hba_wwpn' => $wwpn,
	        'sp' => $sp,
	        'port' => $port,
	        'host' => $host,
	      });
      }
      else
      {
	print "ATTN: ", __LINE__, " storage group data: no match l1='$l1' l2='$l2'\n";
      }
    }
  }
  elsif ($what eq 'hlu_alu') # host lun to array lun mapping
  {
    shift (@$item); # header line
    shift (@$item); # separator line
    while (@$item)
    {
      my $l= shift (@$item);

      if ($l =~ m#^Shareable:\s+(.+)#)
      {
        $obj->{'Shareable'}= $1;
      }
      elsif ($l =~ m#^\s+(\d+)\s+(\d+)#)
      {
	my ($hlu, $alu)= ($1, $2);
	$obj->{'hlu_alu'}->{$hlu}= $alu;
	$obj->{'alu_hlu'}->{$alu}= $hlu;
      }
      else
      {
	print __LINE__, " >>>>> hlu_alu line not matched l='$l'\n";
      }
    }
  }
  elsif ($what eq 'hlu_slu') # host lun to snap lun(?) mapping
  {
    shift (@$item); # header line
    shift (@$item); # separator line
    while (@$item)
    {
      my $l= shift (@$item);

      if ($l =~ m#^Shareable:\s+(.+)#)
      {
        $obj->{'Shareable'}= $1;
      }
      elsif ($l =~ m#^\s+(\d+)\s+([\da-fA-F:]+)\s+(.+)#)
      {
	my ($hlu, $slu, $name)= ($1, $2, $3);
	$obj->{'hlu_slu'}->{$hlu}= $slu;
	$obj->{'slu_hlu'}->{$slu}= $hlu;
	$obj->{'slu_name'}->{$slu}= $name;
      }
      else
      {
	print __LINE__, " >>>>> hlu_slu line not matched l='$l'\n";
      }
    }
  }
  elsif ($what eq 'hlu_sp') # HBA and Storage Processor mapping
  {
    shift (@$item); # header line
    shift (@$item); # separator line

    my $hba_sp_obj= {};
    while (@$item)
    {
      my $l= shift (@$item);

      if ($l =~ m#^\s+([\da-fA-F:]+)\s+SP ([AB])\s+(\d+)#)
      {
	my ($hba, $sp, $port)= ($1, $2, $3);

        $hba_sp_obj=
	{
	  'hba' => $hba,
	  'sp' => $sp,
	  'port' => $port
	};

	push (@{$obj->{'hba_sp'}}, $hba_sp_obj);
      }
      elsif ($l =~ m#^\s*Host name:\s+(.+)#)   # Note: host name my contain blanks :-/
      {
        $hba_sp_obj->{'hostname'}= $1;
      }
      else
      {
	print __LINE__, " >>>>> hba_sp line not matched l='$l'\n";
      }
    }
  }
  else
  {
    print __LINE__, " >>> unknown segment type: '$what'\n";
    &main::print_refs (*STDOUT, 'segment_item_' . $what, $item);
  }
}

sub split_wwn
{
  my $wwn= shift;
  (substr ($wwn, 0, 23), substr ($wwn, 24, 23));
}

sub get_hba_summary
{
  my $sg_obj= shift;

  my $hba_list= $sg_obj->{'hba'};
  my $summary= {};
  my $sum= {};
  foreach my $hba (@$hba_list)
  {
    # &main::print_refs (*STDOUT, 'hba' => $hba);
    my ($host, $wwnn, $wwpn)= map { $hba->{$_} } qw(host hba_wwnn hba_wwpn);
    $summary->{$host}->{$wwnn}->{$wwpn}++;
    $sum->{sprintf ("%-32s %s %s", $host, $wwnn, $wwpn)}++;
  }

  ($summary, $sum);
}

sub print_csv_header
{
  local *FO= shift;

  my $CSV_SEP= shift || ';';

  print FO join ($CSV_SEP, qw(san sg_name hlu alu rg_id rt mb mb_raw UID name)), "\n";

}

1;

__END__

=cut

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over

