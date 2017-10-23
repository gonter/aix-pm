#
# $Id: Config.pm,v 1.39 2012/05/12 13:23:54 gonter Exp $
#

=pod

=head1 NAME

EMC CLARiiON Configuration

=head1 SYNOPSIS

  use EMC::Config;
  my $config= new EMC::Config;

=cut

use strict;

package EMC::Config;

use EMC::Config::Disk;
use EMC::Config::CRU;
use EMC::Config::RaidGroup;
use EMC::Config::LUN;
use EMC::Config::MetaLUN;
use EMC::Config::StorageGroup;
use EMC::Config::Port;

use Data::Dumper;
$Data::Dumper::Indent= 1;

*gb= *EMC::Config::RaidGroup::gb;   # blocks to gigabyte
*mb= *EMC::Config::RaidGroup::mb;   # blocks to megabyte

my $CSV_SEP= ';';
my $SANOPS= 'SANOPS';

my %SKIP_TEXT= map { $_ => 1 }
(
  'Statistics logging is disabled.',
  ' Certain fields are not printed if statistics',
  ' logging is not enabled.'
);

sub new
{
  my $class= shift;
  my %par= @_;

  my $config=
  {
    'enclosure' => {},
    'disk' => {},
    'lun' => {},
    'rg' => {},
    'item_type' => {}, # counts how often each item type was found/parsed
  };
  
  bless $config, $class;

  $config;
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

=pod

=head2 $cnf->analyze_config_data ($items)

Cook until done.  Takes list of items produced by file_splitter and
feeds them to analyze_config_items

=cut

sub analyze_config_data
{
  my $obj= shift;
  my $items= shift;

# &print_refs (*STDOUT, "items", $items);
  my $last_item_type;
  while (scalar @$items)
  {
    my ($item_type, $item_obj)= $obj->analyze_config_items ($items);
    if ($item_type eq 'unknown')
    {
      print __FILE__, ' ', __LINE__, " item_type='$item_type' last_item_type='$last_item_type'\n";
    }
    $obj->{'item_type'}->{$item_type}++;
    $last_item_type= $item_type;
  }
}

=pod

=head2 $cnf->analyze_config_items ($items)

Analyze the next one or more items and let them be parsed by the
appropriate configuration module to extract relevant data and put them
into their rightful objects.

=cut

sub analyze_config_items
{
  my $obj= shift;
  my $items= shift;

  my $item= shift (@$items);

  my $tag= $item->[0];
     $tag= $item->[1] if ($tag =~ /^_LINE_/);

## print __FILE__, ' ', __LINE__, " >>> $tag\n";

  my ($item_type, $item_label, $item_obj);

  if ($tag =~ m#^Bus\s+(\d+)\s+Enclosure\s+(\d+)\s+Disk\s+(\d+)#)
  {
    my ($bus, $encl, $disk)= ($1, $2, $3);

    ($item_type, $item_label, $item_obj)= analyze EMC::Config::Disk ($item);

    $obj->{'disk'}->{$item_label}= $item_obj;
    $obj->{'bus'}->{$bus}->{'enclosure'}->{$encl}->{'disk'}->{$disk}= $item_obj;
  }
  elsif ($tag =~ m#^RaidGroup ID:#)
  {
    ($item_type, $item_label, $item_obj)= analyze EMC::Config::RaidGroup ($item);
    $obj->{'rg'}->{$item_label}= $item_obj;
  }
  elsif ($tag =~ m#^SPE\d+ Enclosure SPE#)
  { # "Service Processor Enclusure two" Enclossure; so much redundancy...
    ($item_type, $item_label, $item_obj)= analyze EMC::Config::CRU ($item);
    $obj->{'enclosure'}->{$item_label}= $item_obj;
    $obj->{'SPE'}= $item_obj; # assuming there is only one SPE
  }
  elsif ($tag =~ m#^DAE3P Bus (\d+) Enclosure (\d+)#)
  {
    my ($bus, $encl)= ($1, $2);

    ($item_type, $item_label, $item_obj)= analyze EMC::Config::CRU ($item);

    $obj->{'enclosure'}->{$item_label}= $item_obj;
    $obj->{'bus'}->{$bus}->{'enclosure'}->{$encl}->{'object'}= $item_obj;
  }
  elsif ($tag =~ m#^D[AP]E4AX Enclosure (\d+)#)
  { # DPAE4AX Enclosure 0, DAE4AX Enclosure 1             
    my $encl= $1;
    my $bus= 0; # AX system only have one bus, numbered 0

    ($item_type, $item_label, $item_obj)= analyze EMC::Config::CRU ($item);

    $obj->{'enclosure'}->{$item_label}= $item_obj;
    $obj->{'bus'}->{$bus}->{'enclosure'}->{$encl}->{'object'}= $item_obj;
  }
  elsif ($tag =~ m#LOGICAL UNIT NUMBER \d+#)
  {
    ($item_type, $item_label, $item_obj)= analyze EMC::Config::LUN ($item);

    $obj->{'lun'}->{$item_label}= $item_obj;
   # print __LINE__, " item_type='$item_type' item_label='$item_label'\n";

    $item_obj->segment ('c1',  shift (@$items));
    $item_obj->segment ('c2',  shift (@$items));
    $item_obj->segment ('st1', shift (@$items));

    if ($items->[0]->[0] =~ m#^Read Histogram#)
    { # normal LUN
      $item_obj->segment ('rh',  shift (@$items));
      $item_obj->segment ('wh',  shift (@$items));
    }
    $item_obj->segment ('st2', shift (@$items));

    while ($items->[0]->[0] =~ m#^Bus\s+\d+\s+Enclosure\s+\d+\s+Disk\s+\d+#)
    {
## print join (' ', __FILE__, __LINE__, $items->[0]->[0]), "\n";
      $item_obj->segment ('disk', shift (@$items));
    }
  }
  elsif ($tag =~ m#MetaLUN Number:\s+\d+#)
  {
    ($item_type, $item_label, $item_obj)= analyze EMC::Config::MetaLUN ($item);

    $obj->{'metalun'}->{$item_label}= $item_obj;

    ## print __LINE__, " item_type='$item_type' item_label='$item_label'\n";
    ## &main::print_refs (*STDOUT, "item_obj", $item_obj);
  }
  elsif ($tag =~ m#Storage Group Name:\s+(.+)#)
  {
    ($item_type, $item_label, $item_obj)= analyze EMC::Config::StorageGroup ($item);
    ## print __LINE__, " item_type='$item_type' item_label='$item_label'\n";

    # look ahead to see if HBA UID definitions are following
    if ($items->[0]->[0] =~ m#^  HBA UID#)
    {
      $item_obj->segment ('hba_uid', shift (@$items));
    }

    # now, look ahead to see if HLU/ALU pairs are defined
    if ($items->[0]->[0] =~ m#^HLU/ALU Pairs:#
        && $items->[1]->[0] =~ m#^  HLU Number\s+ALU Number#)
    {
      shift (@$items); # skip that stuff, it's only a header
      $item_obj->segment ('hlu_alu', shift (@$items));
    }

    if ($items->[0]->[0] =~ m#^HLU/SLU Pairs:#
        &&  $items->[1]->[0] =~ m#^\s+HLU No.\s+SNAP SHOT UID\s+SNAP SHOT NAME#
       )
    {
      shift (@$items); # skip that stuff, it's only a header
      $item_obj->segment ('hlu_slu', shift (@$items));
    }

    if ($items->[0]->[0] =~ m#^HBA/SP Pairs:#
        &&  $items->[1]->[0] =~ m#^\s+HBA UID\s+SP Name\s+SPPort#
       )
    {
      shift (@$items); # skip that stuff, it's only a header
      $item_obj->segment ('hlu_sp', shift (@$items));
    }

    if ($items->[0]->[0] =~ m#^\s+HBA UID\s+SP Name\s+SPPort#)
    { # the HBA/SP line may also be in the first config segment
      $item_obj->segment ('hlu_sp', shift (@$items));
    }

    $obj->{'sg'}->{$item_label}= $item_obj;

    my ($sg_uid, $sg_name)= map { $item_obj->{$_} } ('Storage Group UID', 'Storage Group Name');
    $obj->{'sg_uid'}->{$sg_uid}= $sg_name;

    # &main::print_refs (*STDOUT, "item_obj", $item_obj);
  }
  elsif ($tag =~ m#^Total number of initiators:\s+(\d+)#) # output of the command "port -list -all", first part
  {
    my $initiators= $1;

    $item_type= 'SPPORT1';
    ## shift (@$items); # skip that stuff, it's only a header is it??

    $item_obj= $obj->{'Port'}= new EMC::Config::Port ('initiators' => $initiators)
      unless (defined ($item_obj= $obj->{'Port'})); # TODO: Port is not a smart name, think about something more appropriate

    for (;;)
    {
      $item= $items->[0];
      my $t2= $item->[0];
         $t2= $item->[1] if ($t2 =~ /^_LINE_/);

      last unless ($t2 =~ /^SP Name/);
      shift (@$items);

      $item_obj->analyze_sp_port ($item);
    }
  }
  elsif ($tag =~ m#^Information about each SPPORT:#)
  {
    # output of the command "port -list -all", third and final part
    # also, "port -list -sp" contains exactly the same output
  
    ## shift (@$items); # skip that stuff, it's only a header ????? is it??

    $item_type= 'SPPORT2';
    $item_obj= $obj->{'Port'}= new EMC::Config::Port ()
      unless (defined ($item_obj= $obj->{'Port'})); # TODO: Port is not a smart name, think about something more appropriate

    for (;;)
    {
      $item= $items->[0];
      my $t2= $item->[0];
         $t2= $item->[1] if ($t2 =~ /^_LINE_/);

      last unless ($t2 =~ /^SP Name/);
      shift (@$items);

      $item_obj->analyze_sp_port ($item);
## print join __FILE__, ' ', __LINE__, ' ', Dumper ($item_obj), "\n";
    }
  }
  elsif ($tag =~ m#^Information about each HBA:#) # output of the command "port -list -all", second part or "port -list -hba"
  {
    $item_type= 'HBA';
    $item_obj= $obj->{'Port'}= new EMC::Config::Port ()
      unless (defined ($item_obj= $obj->{'Port'})); # TODO: port is not a smart name, think about something more appropriate

    $item= shift (@$items);
    my $hba_obj= $item_obj->analyze_hba ($item);

    for (;;)
    { # Information about each port of this HBA
      $item= $items->[0];
      my $t2= $item->[0];
         $t2= $item->[1] if ($t2 =~ /^_LINE_/);

      last unless ($t2 =~ /^    SP Name/);
      shift (@$items);

      # for each HBA, there is a section describing it's registered SP ports
      # so we need to analyze SP port data while processing a HBA
      # TODO: tell analyze_sp_port that we are actually dealing with an HBA,
      # otherwise this method will check for fields like 'SP UID'.
      &EMC::Config::Port::analyze_sp_port ($hba_obj, $item);
    }
  }
  elsif (
## @$item == 1 &&
 $tag =~ /^\s*$/) {} # empty line at the end
  else
  { 
    $item_type= 'unknown';
    $item_obj= { 'raw' => $item };  # dummy object
    $item_label= $tag .' '.$item->[1];
    print __FILE__, ' ', __LINE__, " item_type='$item_type' item_label='$item_label'\n";
  }

  ## print __LINE__, " item_type='$item_type' item_label='$item_label'\n";

  if (!$item_type && defined ($item_obj))
  {
    print __LINE__, " ATTN:\n";
    &main::print_refs (*STDOUT, "item_obj", $item_obj);
  }

  ### $item_obj->{'_parent_'}= $obj;
  ## push (@{$obj->{'items'}->{$item_type}}, $item_obj);
  ($item_type, $item_obj);
}

=cut

=head2 $cnf->fixup ()

Copies bits of information between various objects.

=cut

sub fixup
{
  my $obj= shift;

  ## delete ($obj->{'items'}->{'RaidGroup'});
  ## delete ($obj->{'items'}->{'lun'});
  ## delete ($obj->{'items'}->{'disks'});

  $obj->fixup_policy ();
  $obj->fixup_disk_to_rg ();
  $obj->fixup_lun ();
  $obj->fixup_rg_to_lun ();
  $obj->fixup_metalun ();

  $obj->fixup_StorageGroup_to_LUN ();
}

=cut

=head2 $cnf->fixup_policy ()

Copies policy information into actual config data.

=cut

sub fixup_policy
{
  my $obj= shift;

  $obj->fixup_policy_sg ();

  my $port_obj= $obj->{'Port'};
  my $policy_obj= $obj->{'policy'};
  if (defined ($port_obj) && defined ($policy_obj))
  {
    my ($status, $diag)= $port_obj->fixup_policy_port ($policy_obj);
    if ($status)
    {
      print '='x72, "\n";
      print "fixup_policy status=$status\n";
      print join ("\n", @$diag), "\n";
      print '='x72, "\n\n";
    }
  }
}

=cut

=head2 $cnf->fixup_policy_sg

Copy storage group policy information into actual storage group config data.

=cut

sub fixup_policy_sg
{
  my $obj= shift;

  my $o_sg= $obj->{'sg'};
  my $c_sg= $obj->{'sg_uid'};
  my $p_sg= $obj->{'policy'}->{'storagegroups'};

  return -1 unless ($c_sg && $p_sg); # nothing to do unless both data structres exist

# SG1
  foreach my $p_sg_uid (keys %$p_sg)
  {
    my $p_sg_obj= $p_sg->{$p_sg_uid};

    unless (exists ($c_sg->{$p_sg_uid}))
    {
      print "storage group not found: $p_sg_uid\n";
      next;
    }

    my $c_sg_name= $c_sg->{$p_sg_uid};
    my $c_sg_obj= $o_sg->{$c_sg_name};

    map { $c_sg_obj->{$_}= $p_sg_obj->{$_} } ('project', 'comments');
  }
}

=cut

=head2 $cnf->fixup_disk_to_rg

Add cross references for disks to RaidGroup data.

=cut

sub fixup_disk_to_rg
{
  my $obj= shift;

  my $rgp= $obj->{'rg'};
# &main::print_refs (*STDOUT, "rgp", $rgp);
  my $dp= $obj->{'disk'};

  foreach my $dn (keys %$dp)
  {
    my $d= $dp->{$dn};
    my ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns)= $d->Summary1 ();

    next if (!defined($rg_id)
             || $rg_id eq 'This disk does not belong to a RAIDGroup' # real text
             || $rg_id eq 'none' # translated text

             # Hot Spare disks do not belong to RaidGroup 0 as displayed!
             || $state eq 'Hot Spare Ready'  # real text
             || $state eq 'HS_Ready'         # translated text
            );

    # my $rg_label= 'RG_'. $rg_id;
    my $rg_label= $rg_id;
    my $disk_label= join ('_', $bus, $encl, $disk);

    my $rgpp= $rgp->{$rg_label};

    $rgpp->{'disk_count'}++;
    $rgpp->{'disk'}->{$disk_label}= $d;
    $rgpp->{'disk_prods'}->{$prod}++;

    # push LUN offset data from Disk to RG
    my $Private= $d->{'Private'};
    if (exists ($rgpp->{'Private'}))
    {
      if ($rgpp->{'Private'} ne $Private)
      {
	print "ATTN: rg $rg_label private data does not match on disk $disk_label: [$Private] <=> [$rgpp->{'Private'}]\n";
      }
    }
    else
    {
      $rgpp->{'Private'}= $Private;
    }

## print __LINE__, " d='$d'", join (' ', $bus, $encl, $disk, $disk_label, $rg_id, $rg_label, $prod), "\n";
  }

  foreach my $rg_label (keys %$rgp)
  {
    my $rgpp= $rgp->{$rg_label};
    my @disk_prods= keys %{$rgpp->{'disk_prods'}}; # list of disk products in use

    if (@disk_prods == 1)
    {
      $rgpp->{'disk_prod'}= $disk_prods[0];
    }
    elsif (@disk_prods > 1)
    {
      $rgpp->{'disk_prod'}= 'Mixed Disk';  # that's bad, RaidGroup with mixed disk types! brr!
    }
    else
    {
      $rgpp->{'disk_prod'}= 'Unknown Disk';  # that's also bad, RaidGroup without know disk types?
    }
  }
}


=cut

=head2 $cnf->fixup_zerodisk

mark zerodisk status, if available

=cut

sub fixup_zerodisk
{
  my $obj= shift;
  my $zdd= shift;
# print "zdd: ", main::Dumper ($zdd);

  my $dp= $obj->{'disk'};

  foreach my $dn (keys %$dp)
  {
    my $d= $dp->{$dn};
    my ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns)= $d->Summary1 ();

# ZD

    if (exists ($zdd->{$sn}))
    {
      my $d_zdd= $zdd->{$sn}->[0];
      # print "d_zdd: ", main::Dumper ($d_zdd);
      # print "d: ", main::Dumper ($d);
      $d->{'State'}= $d_zdd->{'ZD_status'};
    }
  }

}

=cut

=head2 $cnf->fixup_lun ()

Add cross reference data to LUN information.

=cut

sub fixup_lun
{
  my $obj= shift;

  my $lp= $obj->{'lun'};
  my $rgp= $obj->{'rg'};

  foreach my $ln (keys %$lp)
  {
    my $l= $lp->{$ln};
    my ($lun, $rg_id, $prv, $usage, $raid_type)= $l->get ('LUN', 'RAIDGroup ID', 'Is Private', 'Usage', 'RAID Type');
    # TODO: assert: ln eq lun

    if ($usage eq 'Snap Cache' || $raid_type eq 'Hot Spare')
    { # Snap Caches and Hot Spares are part of SAN operations
      $l->set ('project' => $SANOPS);
      next;
    }

    next if ($prv eq 'Meta');

    if ($rg_id eq 'N/A') # this should only happen if it's a MetaLUN
    { # TODO: usually a component of a MetaLUN, maybe we should check that condition...
      ## print __LINE__, " ATTN: lun=$lun rg_id=$rg_id\n";
      next;
    }

    my $rgpp= $rgp->{$rg_id};

    # add a cross reference for luns to their raid groups
    $rgpp->{'lun'}->{$lun}= $l;

    my $xr= ref ($rgpp);
    unless ($xr eq 'EMC::Config::RaidGroup')
    {
      print __LINE__, " rgpp=$rgpp rgp=$rgp xr='$xr'\n";
      main::print_refs (*STDOUT, 'rgpp', $rgpp);
    }

    # add logical to raw capacity ratio of a RaidGroup to the given LUN
    my ($rg_rc, $rg_lc, $disk_prod)= $rgpp->get ('Raw Capacity (Blocks)', 'Logical Capacity (Blocks)', 'disk_prod');

    $l->{'disk_prod'}= $disk_prod;   # push disk type info into lun object
    if ($rg_rc == 0 or $rg_lc == 0)
    {
      print __LINE__,  " ATTN: lun $ln rg $rg_id: raw cap= $rg_rc, logical cap= $rg_lc\n";
    }
    else
    {
      $l->{'cap_ratio'}= $rg_lc/$rg_rc;  # should give values like 0.5 for raid 1 and 0.8 for raid 5 with 5 disks
      $l->{'LUN RAW Capacity(Megabytes)'}= $l->{'LUN Capacity(Megabytes)'}/($rg_lc/$rg_rc);
    }
  }
}

sub fixup_rg_to_lun
{
  my $obj= shift;

  my $lp= $obj->{'lun'};
  my $rgp= $obj->{'rg'};

  foreach my $rg_id (keys %$rgp)
  {
    my $rgpp= $rgp->{$rg_id};
    next unless (exists ($rgpp->{'Private'}));
    my $Private= $rgpp->{'Private'};
    my $x= _analyze_Private ($Private);

    ## print join (' ', __FILE__, __LINE__, '>>>', $rg_id, $Private), "\n";
    foreach my $xx (@$x)
    {
      my ($lun_id, $offset)= @$xx;
      my $lpp= $lp->{$lun_id};
      $lpp->{'Offset'}= $offset;
      my $cap= $lpp->{'LUN Capacity(Blocks)'};
      $xx->[2]= $cap;
      ## print "lun_id='$lun_id' offset=$offset lpp='$lpp'", Dumper ($lpp), "\n";
    }

    ## print 'x=', Dumper ($x), "\n";
  }
}

=cut

=head2 $cnf->fixup_metalun ()

Add cross reference data to MetaLUNs

=cut

sub fixup_metalun
{
  my $obj= shift;

  my $mlp= $obj->{'metalun'};
  my $lp= $obj->{'lun'};

  foreach my $mln (keys %$mlp)
  {
    my $l= $mlp->{$mln};                   # a metalun is listed as a special MetaLUN object
    my $metalun_lun_object= $lp->{$mln};   # a metalun is also present as LUN object

## main::print_refs (*STDOUT, "l", $l);
## main::print_refs (*STDOUT, "metalun_lun_object", $metalun_lun_object);

    my ($ml_cc_list, $name)= $l->get ('concat components', 'MetaLUN Name');
    ## print join (' ', __LINE__, sort keys %$components), "\n";
    delete ($l->{'disk'});      # nonsense data
    delete ($l->{'disk_stat'}); # nonsense data

    my %disks= ();
    my %raid_types= ();
    my $mb_raw= 0;

    # components are a list of concatinated components, these
    # components are either plain LUNs or striped MetaLUNs

    # so: first walk through list of concatinated components
    foreach my $ml_cc (@$ml_cc_list)
    {
## main::print_refs (*STDOUT, "ml_cc", $ml_cc);
      my $ml_sc_list= $ml_cc->{'stripe components'};
      my %rg_ids;
      foreach my $ml_sc (@$ml_sc_list)
      {
## main::print_refs (*STDOUT, "ml_sc", $ml_sc);
        my $ln= $ml_sc->{'LUN Number'};
        if (exists ($lp->{$ln}))
        {
          my $ll= $lp->{$ln};

          # record membership
          $ll->{'is_part_of_num'}= $mln;
          $ll->{'is_part_of_name'}= $name;
	  my $rg_id= $ll->{'RAIDGroup ID'};
## print __FILE__, " ", __LINE__, " mln=$mln ln=$ln rg_id=$rg_id\n";
	  $rg_ids{$rg_id}++;

          # get a list of disks which are used for that lun
	  my $lun_disk= $ll->{'disk'};
	  foreach my $disk (keys %$lun_disk) { $disks{$disk}++; }
          $raid_types{$ll->{'RAID Type'}}++;
  
	  $mb_raw += $ll->{'LUN RAW Capacity(Megabytes)'};
        }
        else
        { # TODO: data for metalun component not available
          print __LINE__,  " ATTN: data for metalun $mln component $ln not available\n";
        }
      } # end of striped component

      foreach my $rg_id (keys %rg_ids)
      {
        my $rg_cnt= $rg_ids{$rg_id};
## print join (' ', __FILE__, __LINE__, "mln='$mln' rg_id='$rg_id' rg_cnt='$rg_cnt'"), "\n";
        if ($rg_ids{$rg_id} > 1)
        { # several striped components are on one RaidGroup, that's not good!
	  # cite Leininger: "Da fliegen die Koepfe hin und her!"
          $l->{'is_bad'} |= 0x01;
          $metalun_lun_object->{'is_bad'} |= 0x01;
## print join (' ', __FILE__, __LINE__, "marked as bad"), "\n";
        }
      }
    } # end of concatinated component

    $metalun_lun_object->{'disk_count'}=
    $l->{'disk_count'}= scalar keys %disks;

    my @raid_types= keys %raid_types;
    if (@raid_types == 1)
    {
      $l->{'RAID Type'}= $metalun_lun_object->{'RAID Type'}= $raid_types[0];
    }
    else
    {
      $l->{'RAID Type'}= $metalun_lun_object->{'RAID Type'}= 'Mixed';
      $l->{'is_bad'} |= 0x02;
      $metalun_lun_object->{'is_bad'} |= 0x02;
    }
    $l->{'RAID Type'}= $metalun_lun_object->{'RAID Type'}= (@raid_types == 1) ? $raid_types[0] : 'Mixed';
    $metalun_lun_object->{'Is Private'}= 'Meta';

    $metalun_lun_object->{'LUN RAW Capacity(Megabytes)'}= $mb_raw;
if ($mb_raw)
{
    $metalun_lun_object->{'cap_ratio'}= $metalun_lun_object->{'LUN Capacity(Megabytes)'}/$mb_raw;
}
else
{
    $metalun_lun_object->{'cap_ratio'}= 'undefined';
print __FILE__, " ", __LINE__, "ATTN: mb_raw=[$mb_raw] metalun_lun_object: ", main::Dumper ($metalun_lun_object), "\n";
}

## main::print_refs (*STDOUT, "l", $l);
## main::print_refs (*STDOUT, "metalun_lun_object", $metalun_lun_object);

  }
}

=cut

=head2 $obj->fixup_StorageGroup_to_LUN ()

=cut

sub fixup_StorageGroup_to_LUN
{
  my $obj= shift;

  my $sg_l= $obj->{'sg'};
  my $lp=   $obj->{'lun'};
  my $mlp=  $obj->{'metalun'};

  foreach my $sg (keys %$sg_l)
  {
    my $sg_p= $sg_l->{$sg};

    my $project= $sg_p->{'project'};
    my @alus= keys %{$sg_p->{'alu_hlu'}};

    foreach my $alu (@alus)
    {
      my $l= $lp->{$alu};
      $l->{'Storage_Group'}= $sg;
      my ($lun, $rg_id, $prv)= $l->get ('LUN', 'RAIDGroup ID', 'Is Private');
      ## print __LINE__, " ZX4 sg='$sg' alu=$alu rg_id=$rg_id prv='$prv' project='$project'\n";
      $l->{'project'}= $project if ($project);

      if ($prv eq 'Meta')
      {
	## &main::print_refs (*STDOUT, 'lun', $l);
	my $ml= $mlp->{$alu};
	## &main::print_refs (*STDOUT, 'metalun', $ml);

	my $cp= $ml->get ('component');   # list of components
	my @cp_luns= keys %$cp;
	foreach my $cp_lun (@cp_luns)
	{
	  my $cp_l= $lp->{$cp_lun};
	  ## print __LINE__, " ZX5 cp_lun=$cp_lun\n";
	  ## &main::print_refs (*STDOUT, 'metalun', $ml);
          ## my ($cp_ln, $cp_rg_id, $cp_prv)= $l->get ('LUN', 'RAIDGroup ID', 'Is Private'); not really relevant
          $cp_l->{'project'}= $project if ($project);
          $cp_l->{'Storage_Group'}= $sg;
        }
      }
    }
  }
}

=cut

=head2 $cnf->RaidGroupSummary (%parameters)

Print a summary for a RaidGroup

parameters:
  'show_luns' => 0|1    ... display detail information about LUNs in that StorageGroup
=cut

sub RaidGroupSummary
{
  my $obj= shift;
  my %par= @_;

  Summary_Header EMC::Config::RaidGroup;

  my ($T_blk_raw, $T_blk_cap, $T_blk_free);
  my $rgp= $obj->{'rg'};
  foreach my $rg_id (sort { $a <=> $b } keys %$rgp)
  {
    my $rg= $rgp->{$rg_id};
    $rg->Summary ($par{'show_luns'});

    my ($blk_raw, $blk_cap, $blk_free)= $rg->get ('Raw Capacity (Blocks)',
        'Logical Capacity (Blocks)', 'Free Capacity (Blocks,non-contiguous)');

    $T_blk_raw += $blk_raw;
    $T_blk_cap += $blk_cap;
    $T_blk_free += $blk_free;
  }

  my $T_raw=  &gb ($T_blk_raw);
  my $T_cap=  &gb ($T_blk_cap);
  my $T_free= &gb ($T_blk_free);

  print "\n", "-"x70, "\n";
  printf  ("Total Raw Capacity:       %16s blocks, %9d GByte\n", $T_blk_raw, $T_raw);
  printf  ("Total Available Capacity: %16s blocks, %9d GByte\n", $T_blk_cap, $T_cap);
  printf  ("Total Free Capacity:      %16s blocks, %9d GByte\n", $T_blk_free, $T_free);
  print "\n", "-"x70, "\n\n";
}

=cut

=head2 $cnf->RaidGroupDetails ($filename)

Write detail information about Raid Groups to a file in simple CSV format.

=cut

sub RaidGroupDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or die;
  print FO join ($CSV_SEP, 'san', 'rg', 'rt', 'num_disks', 'disks', 'prod', 'luns',
                 'mb_raw', 'mb_cap', 'mb_free', 'mb_free_cont'), "\n";

  my $rp= $obj->{'rg'};
  my $sys= $obj->{'name'};
  foreach my $rn (sort { $a <=> $b } keys %$rp)
  {
    my $r= $rp->{$rn};
    my ($rg_id, $n_disks, $l_disks, $l_luns, $rt, $dp, $blk_raw, $blk_cap,
        $blk_free, $blk_free_cont)= $r->Summary1 ();

    if ($rt eq 'hot_spare')
    {
      $blk_free= 0;  # apparently, getrg shows free capacity for hot spares!
    }

    my $mb_raw= int (&mb ($blk_raw));
    my $mb_cap= int (&mb ($blk_cap));
    my $mb_free= int (&mb ($blk_free));
    my $mb_free_cont= int (&mb ($blk_free_cont));

    print FO join ($CSV_SEP, $sys, $rg_id, $rt, $n_disks, $l_disks, $dp, $l_luns,
                   $mb_raw, $mb_cap, $mb_free, $mb_free_cont), "\n";
  }
  close (FO);
}

=cut

=head2 $cnf->EnclosureSummary (*FILEHANDLE)

Write summary information about enclosures to a filehandle.  Returns a
general system health status and a list of problems.  This may be
useful for monitoring purposes.

=cut

sub EnclosureSummary
{
  my $obj= shift;
  local *FO= shift;
  my $now_s= shift;

  my $not_ok= 0;
  my @problems= ();

  my @REPORT;

  my $SPE;
  if (defined ($SPE= $obj->{'SPE'}) || defined ($SPE= $obj->{'enclosure'}->{'DPE4AX_0_0'}))
  {
    my ($label, $ty, $bus, $encl, $attn, $extended)= $SPE->state ();

      push (@REPORT, "Enclosure SPE: $ty, State: $attn");
      if ($extended)
      {
	push (@REPORT, @$extended);
	push (@problems, @$extended);
      }

      $not_ok++ if ($attn ne 'OK' || $extended);
  }
  else
  {
    print "No processor enclosure known!\n";
    print join (' ', %$obj), "\n";
    $not_ok++;
  }

  my $bp= $obj->{'bus'};
  foreach my $bus (sort { $a <=> $b } keys %$bp)
  {
    my $bo= $bp->{$bus};
    my $ep= $bo->{'enclosure'};
    next unless ($ep);

    foreach my $encl (sort { $a <=> $b } keys %$ep)
    {
      my $epo= $ep->{$encl};
      my $eo= $epo->{'object'};
      my ($label, $ty, $bus, $encl, $attn, $extended)= $eo->state ();

      push (@REPORT, "Bus $bus, Enclosure $encl: $ty, State: $attn");
      if ($extended)
      {
	push (@REPORT, @$extended);
	push (@problems, @$extended);
      }

      $not_ok++ if ($attn ne 'OK' || $extended);
    }
  }

  my $log_line;
  if ($not_ok)
  {
    $log_line= join (' ', 'CRITICAL', '-', $now_s, $not_ok, map { s/\n/ /g; $_; } @problems);
  }
  else
  {
    $log_line= "OK - $now_s";
  }

  print FO $log_line, "\n\n";

  foreach my $r (@REPORT)
  {
    print FO $r, "\n";
  }

  ($not_ok, $log_line, \@problems); 
}

=cut

=head2 $cnf->SystemSummary ()

Write summary information about the system to STDOUT.

=cut

sub SystemSummary
{
  my $obj= shift;

  my $DISK_SUMMARY= {};

  my $bp= $obj->{'bus'};
  foreach my $bus (sort { $a <=> $b } keys %$bp)
  {
    my $bo= $bp->{$bus};
    print '='x 40, "\n", "BUS $bus\n";

    my $ep= $bo->{'enclosure'};
    next unless ($ep);

    foreach my $encl (sort { $a <=> $b } keys %$ep)
    {
      my $epo= $ep->{$encl};

## &main::print_refs (*STDOUT, 'epo', $epo);

      my $eo= $epo->{'object'};
      next unless (defined ($eo));

      my ($label, $ty, $bus, $encl, $attn, $extended)= $eo->state ();
# &main::print_refs (*STDOUT, 'encl_object', $eo);

      print '-'x 40, "\n", "Bus $bus, Enclosure $encl: $ty, State: $attn\n";
      EMC::Config::Disk->Summary_Header  ();

      my $dp= $epo->{'disk'};
      foreach my $disk ( sort { $a <=> $b } keys %$dp)
      {
	my $do= $dp->{$disk};
	$do->Summary ();
	my ($pid, $state, $rgid, $cap)=
	   $do->get ('Product Id', 'State', 'Raid Group ID', 'Capacity');

	if ($state eq 'Empty')
	{
	  $DISK_SUMMARY->{$state}->{'TOTAL'}++;
	}
	else
	{
	  $state= 'HS_ready' if ($state eq 'Hot Spare Ready');
	  $DISK_SUMMARY->{$pid}->{$state}++;
	  $DISK_SUMMARY->{$pid}->{'TOTAL'}++;
	}
      }

      if ($extended)
      {
	print join ("\n", @$extended), "\n";
      }

    }
  }

  print "\n";
  print "-"x 60, "\n";
  my @labels= qw(TOTAL Enabled HS_ready Unbound);
  printf ("%18s ", 'Product');
  foreach my $label (@labels) { printf (" %8s", $label); }
  printf (" other\n");

  foreach my $pid (sort keys %$DISK_SUMMARY)
  {
    printf ("%18s ", $pid);
    my $p= $DISK_SUMMARY->{$pid};

    foreach my $label (@labels)
    {
      printf (" %8d", $p->{$label});
      delete $p->{$label};
    }

    foreach my $label (sort keys %$p)
    {
      printf (" %s: %d", $label, $p->{$label});
    }
    
    print "\n";
  }
}

sub DiskSummary
{
  my $obj= shift;

  Summary_Header EMC::Config::Disk;

  my $dp= $obj->{'disk'};
  foreach my $dn (sort keys %$dp)
  {
    my $d= $dp->{$dn};
    $d->Summary ();
  }

}

sub DiskDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or die;
  # Summary_Header EMC::Config::Disk;
  print FO join ($CSV_SEP, 'san', 'bus', 'encl', 'disk', 'prod', 'sn', 'state', 'rg_id', 'capacity', 'n_luns', 'replacing', 'pct_busy', 'TLA_pn'), "\n";

  my $dp= $obj->{'disk'};
  my $sys= $obj->{'name'};
  foreach my $dn (sort keys %$dp)
  {
    my $d= $dp->{$dn};
    my ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns, $hsr, $pct_busy, $tla_pn)= $d->Summary1 ();

    print FO join ($CSV_SEP, $sys, $bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns, $hsr, $pct_busy, $tla_pn), "\n";
  }
  close (FO);
}

# 2009-02-27 TODO
# 2009-11-01 I think this was the start of a perfomance logging function?
sub DiskBusy
{
  my $obj= shift;
  my $ts=  shift;
  my $fnm= shift;

  my $write_header= (-f $fnm) ? 0 : 1;
  open (FO, '>>'. $fnm) or die;
  # Summary_Header EMC::Config::Disk;
  if ($write_header)
  {
    print FO join ($CSV_SEP, 'ts', 'san', 'bus', 'encl', 'disk',
		   'rg_id', 'n_luns',
                   'rd_rq', 'rd_kb', 'wr_rq', 'wr_kb', 'sbc'), "\n"
  }

  my $dp= $obj->{'disk'};
  my $sys= $obj->{'name'};
  foreach my $dn (sort keys %$dp)
  {
    my $d= $dp->{$dn};
    my @r= $d->Busy ();
    print FO join ($CSV_SEP, $ts, $sys, @r), "\n";
  }
  close (FO);
}

sub LUNSummary
{
  my $obj= shift;

  Summary_Header EMC::Config::LUN;

  my $lp= $obj->{'lun'};
  foreach my $ln (sort { $a <=> $b } keys %$lp)
  {
    my $l= $lp->{$ln};
# print __LINE__, " l='$l'\n";
    $l->Summary ();
  }
}

sub LUNDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or die;

  EMC::Config::LUN::print_csv_header (*FO);

  my $lp= $obj->{'lun'};
  my $sys= $obj->{'name'};
  foreach my $ln (sort { $a <=> $b } keys %$lp)
  {
    my $l= $lp->{$ln};
## print __FILE__, ' ', __LINE__, " l='$l'\n";
    $l->print_as_csv (*FO, $sys);
  }
  close (FO);
}

sub to_csv
{
  my $s= shift;
  my $quote= 0;

  $s= '"'. $s . '"' if ($s =~ /:/);

  $s;
}

sub StorageGroupSummary
{
  my $obj= shift;
  my %par= @_;

  my $sg= $obj->{'sg'};

  foreach my $sg_name (sort keys %$sg)
  {
    $obj->StorageGroupDetails ($sg_name, $par{'show_luns'}, $par{'show_hosts'});
  }
}

sub StorageGroupDetails
{
  my $obj= shift;
  my $sg_name= shift;
  my $show_luns= shift;
  my $show_hosts= shift;

  my $sg_obj= $obj->{'sg'}->{$sg_name};
  print "storage group: $sg_name\n";

  if ($show_luns || $show_hosts)
  {
    my ($project, $comments)= map { $sg_obj->{$_} } qw(project comments);
    print "project: $project ($comments)\n";
  }

  if ($show_luns)
  {
    my @sg_hlus= sort { $a <=> $b } keys %{$sg_obj->{'hlu_alu'}};

    my ($t_cnt, $t_mb, $t_mb_raw)= (0, 0, 0);
    printf ("HLU ");
    Summary_Header EMC::Config::LUN;
    foreach my $hlu (@sg_hlus)
    {
      my $alu= $sg_obj->{'hlu_alu'}->{$hlu};

      my $l= $obj->{'lun'}->{$alu};
      next unless (defined ($l)); # XXX
# print "LUN: $lun\n";
      printf ("%3d ", $hlu);
      my ($mb, $mb_raw)= $l->Summary ();   # XXX sad crashes here when only sg data is supplied, because there is simply no LUN data available
      $t_cnt++;
      $t_mb     += $mb;
      $t_mb_raw += $mb_raw;
    }

    printf ("  LUN usage: %d LUNs, %d GB, %d GB raw\n", $t_cnt, $t_mb/1024, $t_mb_raw/1024);
  }

  if ($show_hosts)
  {
    my ($s1, $s2)= $sg_obj->get_hba_summary ();
    foreach my $s (sort keys %$s2)
    {
      print "  ", $s, " ", $s2->{$s}, "\n";
    }
  }

  print "\n" if ($show_luns || $show_hosts);
}

sub StorageGroupLUNDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or die;

## print "writing to '$fnm'\n";
  EMC::Config::StorageGroup::print_csv_header (*FO);

  my $sg= $obj->{'sg'};
  my $sys= $obj->{'name'};
  foreach my $sg_name (sort keys %$sg)
  {
    my $sg_obj= $sg->{$sg_name};
    &print_SG_LUNs_as_csv (*FO, $obj, $sg_obj, $sg_name, $sys);
  }
  close (FO);
}

sub print_SG_LUNs_as_csv
{
  local *FO= shift;
  my $obj= shift;
  my $sg_obj= shift;
  my $sg_name= shift;
  my $sys= shift;
  my $CSV_SEP= shift || ';';

  return 0 unless $sg_obj;
## print __LINE__, " storage group: $sg_name\n";

    my @sg_hlus= sort { $a <=> $b } keys %{$sg_obj->{'hlu_alu'}};

    foreach my $hlu (@sg_hlus)
    {
      my $alu= $sg_obj->{'hlu_alu'}->{$hlu};

      my $l= $obj->{'lun'}->{$alu};
      next unless (defined ($l)); # XXX
## print "hlu: $hlu, alu: $alu\n";

    my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name,
        $cap_ratio, $mb_raw, $project, $disk_prod, $uid, $parent_lun,
        $def_own, $cur_own, $aa, $is_bad, $wc, $rc, $sg)=
       $l->Summary1 ();

      print FO join ($CSV_SEP, $sys, $sg_name, $hlu, $alu, $rg_id, $rt, $mb, $mb_raw, $uid, $name), "\n";

    }

  1;
}

=cut

=head $cnf->show_SGT (*FILEHANDLE)

Write a dummy policy stanza for a storage group that does not have
one.

=cut

sub show_SGT
{
  my $obj= shift;
  local *FO= shift;

  my $sg= $obj->{'sg'};
  my $name= $obj->{'name'};

srand ($$ ^ time ());
  foreach my $sg_name (sort keys %$sg)
  {
    my $sg_obj= $sg->{$sg_name};
    my ($sg_n, $sg_uid, $project)= map { $sg_obj->{$_} } ('Storage Group Name', 'Storage Group UID', 'project');
    ## print join ('|', $sg_uid, $sg_n, $sg_name, $project), "\n";
    next if ($project);

    my $num= int (rand (10000));   # thats just for a random label

    # AIX::NIM::Config stanza format
    print FO <<EOX;
sg_$num:
  class = policy
  type = storagegroup
  san = $name
  project = unknown
  sg_uid = $sg_uid
  sg_name = $sg_n
EOX
  }
}

=cut

=head2 $cnf->file_splitter ($filename)

Split configuration data file along blank lines in order to pre-parse
configuration data into separate chunks which need to be analyzed and
possibly aggregated later on.

=cut

sub file_splitter
{
  my $obj= shift;
  my $fnm= shift;

  my @res;
  my $l= [];

  open (FI, $fnm) or die "cant read $fnm";
  ## print "reading $fnm\n";  # XXX: if verbose
  $obj->{'files_read'}->{$fnm}++;
  my $lnr= 0;
  while (<FI>)
  {
    chop;
    $lnr++;

    next if exists ($SKIP_TEXT{$_});

# print "[$_]\n";
    if (/^\s?$/) # MetaLUN listings have one blank in the separator line
    {
      if (@$l)
      {
        push (@res, $l);
# print __LINE__, " >>> ", join (':', @$l), "\n";
        # print "pushing...\n"
        $l= [];
      }

      next;
    }

# print "[[$_]]\n";
    push (@$l, $_);
    # if ($#$l == 0) { push (@$l, '_LINE_ '.$lnr); }
  }
  close (FI);

  if (@$l)
  {
    push (@res, $l);
# print join (':', @$l), "\n";
    # print "pushing...\n"
  }

# print join (':', @res), "\n";
  (wantarray) ? @res : \@res;
}

sub print_hba_port_info
{
  my $obj= shift;

  return undef unless (defined ($obj->{'Port'}->{'HBA_list'}));

  my @HBA_list= @{$obj->{'Port'}->{'HBA_list'}};
  foreach my $hba_p (@HBA_list)
  {
    ## print "hba_p='$hba_p'\n";
    $hba_p->print_hba_port_info ();
  }
}

=cut

=head2 $cnf->HBAPortDetails ($filename)

export data about each known HBA in CSV format.

=cut

sub HBAPortDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or return undef;
  &EMC::Config::Port::HBA::print_csv_header (*FO, $CSV_SEP);

  my $lines= 0;
  my $sys= $obj->{'name'};
  my @HBA_list= @{$obj->{'Port'}->{'HBA_list'}};
  foreach my $hba_p (@HBA_list)
  {
    ## print "hba_p='$hba_p'\n";
    $lines += $hba_p->print_as_csv (*FO, $sys, $CSV_SEP);
  }
  close (FO);

  $lines;
}

=cut

=head2 $cnf->SPPortDetails ($filename)

export SP Port data in CSV format.

=cut

sub SPPortDetails
{
  my $obj= shift;
  my $fnm= shift;

  open (FO, '>'. $fnm) or return undef;
  &EMC::Config::Port::SPPort::print_csv_header (*FO, $CSV_SEP);

  my $lines= 0;
  my $sys= $obj->{'name'};
  my $sp_pp= $obj->{'Port'}->{'SP'};
  foreach my $sp (sort keys %$sp_pp)
  {
    my $p_p= $sp_pp->{$sp}->{'port'};
    foreach my $pnum (sort { $a <=> $b } keys %$p_p)
    {
      my $p_obj= $p_p->{$pnum};
## print __FILE__, ' ', __LINE__, " p_obj='$p_obj'\n";
      $lines += $p_obj->print_as_csv (*FO, $sys, $CSV_SEP);
    }
  }
  close (FO);

  $lines;
}

sub _analyze_Private
{
  my $p= shift;

  my @l;
  # $p=~ s/(\d+): (\d+)/$l{$1}= $2/ge;
  $p=~ s/(\d+): (\d+)/push (@l, [ $1, $2 ])/ge;
  
  \@l;
}

1;

=cut

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over

