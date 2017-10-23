#
# $Id: LUN.pm,v 1.15 2009/08/26 15:18:25 gonter Exp $
#

use strict;

package EMC::Config::LUN;

use EMC::Config::Disk;

sub new
{
  my $class= shift;

  my $lun_id= shift;

  my $lun_obj=
  {
    'LUN' => $lun_id,
  };

  bless $lun_obj, $class;
  $lun_obj;
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

sub get
{
  my $obj= shift;
  my @par= @_;

  my @res;
  foreach my $par (@par)
  {
    push (@res, $obj->{$par});
  }

  (wantarray) ? @res : \@res;
}

sub analyze
{
  my $cl_or_obj= shift;
  my $item= shift;

  # print __LINE__, " cl_or_obj='$cl_or_obj'\n";

  my $tag= $item->[0];
  return ('invalid', $tag, $item) unless ($tag =~ m#LOGICAL UNIT NUMBER (\d+)#);

  my $lun_id= $1;
  my $label= $lun_id;

  my $lun_obj= new EMC::Config::LUN ($lun_id);
  $lun_obj->{'label'}= $label;

  my @l= @$item;
  shift (@l);

  foreach my $l (@l)
  {
    if ($l =~ /^([\w ]+)\s+=\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($1, $2);
      $lun_obj->{$kw}= $val;
    }
    else
    {
      # print __LINE__, " >>> '$l'\n";
    }
  }

  ('lun', $label, $lun_obj);
}

#
sub segment
{
  my $obj= shift;
  my $what= shift;
  my $item= shift;

  # &main::print_refs (*STDOUT, 'segment_item', $item);

  my @l= @$item;

  if ($what eq 'disk')
  {
    # Immediately following the last disk data block there are another
    # few lines of config data.  We remove these lines from the disk
    # block and feed them into this method again.

    my $trail;
    my $lc= @l;
    if ($l[13] =~ /^Is Private/) { $trail= 13; }
    elsif ($l[1] =~ /^Is Private/) { $trail= 1; }
    elsif ($lc == 1 || $lc == 13) { } # NOP, there is no extra data
    else { print __LINE__, " ATTN: trailing block not found: lc=$lc $l[0]\n"; }

    if ($trail)
    {
      my @r= splice (@l, $trail);
      $obj->segment ('x2', \@r) if (@r);
    }

    # Disk data is more or less structured the same as output from "navicl getdisk"
    my ($item_type, $item_label, $item_obj)= analyze EMC::Config::Disk (\@l);
    $obj->{'disk'}->{$item_label}= $item_obj;
    $obj->{'disk_count'}++;
  }
  elsif ($what eq 'rh' || $what eq 'wh')
  {
    foreach my $l (@l)
    {
      if ($l =~ /((Read|Write) Histogram)\[(\d+)\]\s*(\d+)/)
      {
	my ($rwh, $rw, $idx, $val)= ($1, $2, $3, $4);
	$obj->{$rwh}->[$idx]= $val;
      }
      elsif ($l =~ /(Read|Write) Histogram overflows\s*(\d+)/)
      {
	my ($rw, $val)= ($1, $2);
	$obj->{$rw . '_histogram_overflows'}= $val;
      }
      else { } # TODO: warning or whatever
    }
  }
  elsif ($what eq 'st1')
  {
    foreach my $l (@l)
    {
      if ($l =~ /Name\s+(.+)/)
      {
	$obj->{'Name'}= $1;
      }
      elsif ($l =~ /Minimum latency reads\s+(.+)/)
      {
	$obj->{'Minimum latency reads'}= $1;
      }
      elsif ($l =~ /(.+):\s+(.+)/)
      {
	my ($field, $val)= ($1, $2);
	$obj->{$field}= $val;
      }
    }
  }
  elsif ($what eq 'x2' || $what eq 'st2')
  {
    foreach my $l (@l)
    {
      if ($l =~ /^Bus\s+(\d+)\s+Enclosure\s+(\d+)\s+Disk\s+(\d+)\s+(.+):\s+(.+)$/)
      {
	my ($bus, $encl, $disk, $par, $val)= ($1, $2, $3, $4, $5);
	my $label= join ('_', $bus, $encl, $disk);
	$obj->{'disk_stat'}->{$label}->{$par}= $val;
      }
      elsif ($l =~ /(.+):\s+(.+)/)
      {
	my ($field, $val)= ($1, $2);
	$obj->{$field}= $val;
      }
    }
  }
}

sub Summary_Header
{
  shift;
  my $sp= shift;

  print ' ' x$sp;
  printf ("%3s %4s %7s %7s %4s %5s %7s %6s %6s %3s %s\n",
	 'RG', 'LUN', 'Type', 'capa', 'Disks', 'priv', 'State',
	 'DefOwn', 'CurOwn', 'AA', 'Name');
}

sub Summary1
{
  my $obj= shift;

  my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name, $cap_ratio, $mb_raw,
      $project, $disk_prod, $uid, $parent_lun, $def_own, $cur_own, $aa, $is_bad,
      $wc, $rc, $sg)=
     map { $obj->{$_} }
     ( 'LUN', 'RAIDGroup ID', 'RAID Type', 'Offset',
       'LUN Capacity(Megabytes)', 'Is Private',
       'disk_count', 'State', 'Name', 'cap_ratio',
       'LUN RAW Capacity(Megabytes)', 'project',
       'disk_prod', 'UID', 'is_part_of_num',
       'Default Owner', 'Current owner',
       'Auto-assign', 'is_bad',
       'Write cache', 'Read cache', 'Storage_Group',
     );

  if ($rt eq 'Hot Spare')
  {
    $rt= 'HS';
  }
  elsif ($rt eq 'N/A')
  {
    $priv= 'Meta';
  }

  unless ($off eq 'N/A') # MetaLUNs do not have an Offset
  {
    $off= ($off-69704)/2048; # offset in blocks, 69704 blocks appear to be used internally
  }

  $priv .= '*' if ($is_bad);
  $aa= ($aa eq 'ENABLED') ? 'on' : 'off';

  ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name, $cap_ratio, $mb_raw,
   $project, $disk_prod, $uid, $parent_lun, $def_own, $cur_own, $aa, $is_bad, $wc, $rc, $sg);
}

sub Summary
{
  my $obj= shift;
  my $sp= shift;

  my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name, $cap_ratio, $mb_raw,
      $project, $disk_prod, $uid, $parent_lun, $def_own, $cur_own, $aa)= $obj->Summary1 ();

  my $gb= $mb / 1024;

  if ($priv eq 'YES' && $rt ne 'HS')
  {
    my ($l_usage, $ml_num, $ml_name)= $obj->get ('Usage', 'is_part_of_num', 'is_part_of_name');

    if ($l_usage eq 'Snap Cache')
    {
      $name= "[$name] Snap Cache"
    }
    else
    {
      $name= "[$name] belongs to MetaLUN $ml_num: $ml_name";
    }
  }

  print ' ' x$sp;
  printf ("%3d %4d %7s %7.2f %5d %5s %7s %6s %6s %3s %s\n",
	  $rg_id, $lun, $rt, $gb, $n_disk, $priv, $state, $def_own,
	  $cur_own, $aa, $name);

  ($mb, $mb_raw);
}

sub print_csv_header
{ 
  local *FO= shift;

  my $CSV_SEP= shift || ';';

  print FO join ($CSV_SEP, 'san',
                 'lun', 'rg_id', 'rt', 'off', 'mb',
                 'mb_raw', 'cap_ratio', 'priv', 'n_disk', 'disk_prod',
                 'state', 'name', 'project', 'UID', 'parent_lun',
                 'def_own', 'cur_own', 'auto_assign', 'is_bad', 'wc', 'rc', 'sg'),
           "\n";
}

sub print_as_csv
{ 
  my $l= shift;
  local *FO= shift;
  my $sys= shift;
  my $CSV_SEP= shift || ';';

  return 0 unless $l;

    my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name,
	$cap_ratio, $mb_raw, $project, $disk_prod, $uid, $parent_lun,
	$def_own, $cur_own, $aa, $is_bad, $wc, $rc, $sg)=
       $l->Summary1 ();

    ($name, $project)= map { &EMC::Config::to_csv ($_); } ($name, $project);

    print FO join ($CSV_SEP, $sys,
                   $lun, $rg_id, $rt, $off, $mb,
                   $mb_raw, $cap_ratio, $priv, $n_disk, $disk_prod,
                   $state, $name, $project, $uid, $parent_lun,
                   $def_own, $cur_own, $aa, $is_bad, $wc, $rc, $sg),
             "\n";

  1;
}

1;

