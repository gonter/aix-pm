#
# $Id: MetaLUN.pm,v 1.3 2008/05/16 11:31:04 gonter Exp $
#

use strict;

package EMC::Config::MetaLUN;

use EMC::Config::Disk;

sub new
{
  my $class= shift;

  my $metalun_id= shift;

  my $metalun_obj=
  {
    'MetaLUN' => $metalun_id,
  };

  bless $metalun_obj, $class;
  $metalun_obj;
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

  ## &main::print_refs (*STDOUT, 'item', $item);
  # print __LINE__, " cl_or_obj='$cl_or_obj'\n";

  my $tag= $item->[0];
  return ('invalid', $tag, $item) unless ($tag =~ m#^MetaLUN Number:\s+(\d+)#);

  my $metalun_id= $1;
  my $label= $metalun_id;

  my $metalun_obj= new EMC::Config::MetaLUN ($metalun_id);
  $metalun_obj->{'label'}= $label;

  my @l= @$item;
  shift (@l);

  my $state= 'std';

  my $cc= undef; # concat component
  my $cc_idx= 0;
  my $sc= undef; # stripe component
  my $sc_idx= 0;

  foreach my $l (@l)
  {
## print __LINE__, " >>> '$l'\n";
    if ($l =~ /((Read|Write) Histogram)\[(\d+)\]:\s*(\d+)/)
    { # Read Histogram[9]:  0
      # Write Histogram[9]:  304724
      my ($rwh, $rw, $idx, $val)= ($1, $2, $3, $4);
      $metalun_obj->{$rwh}->[$idx]= $val;
    }
    elsif ($l =~ /(Read|Write) Histogram overflows\s*(\d+)/)
    {
      my ($rw, $val)= ($1, $2);
      $metalun_obj->{$rw . '_histogram_overflows'}= $val;
    }
    elsif ($l =~ m#^((Total|Actual) User Capacity) \(Blocks/Megabytes\):\s+(\d+)/(\d+)#)
    { # Total User Capacity (Blocks/Megabytes):  1073741824/524288
      # Actual User Capacity (Blocks/Megabytes):  1073741824/524288
      my ($tac, $tac_kw, $cb, $cm)= ($1, $2, $3, $4);
      $metalun_obj->{$tac_kw . ' Blocks'}= $cb;
      $metalun_obj->{$tac_kw . ' Megabytes'}= $cm;
    }
    elsif ($l=~ /Components:\s+$/)
    { # now follows a list of LUNs which are used for concat and stripe expansion
      $state= 'cc';
    }
    elsif ($l=~ /^(Number of LUNs):\s+(\d+)/)
    { # these is one concat component, consisting of one or mor stripe components
      my ($kw, $num_luns)= ($1, $2);
      $cc= { $kw => $num_luns, 'stripe components' => [] };
      $metalun_obj->{'concat components'}->[$cc_idx++]= $cc;
    }
    elsif ($l=~ /LUNs:\s+$/)
    { # now follows a list of stripe component LUNs which are member of this stripe set
      $state= 'sc';
      $sc_idx= 0;
    }
    elsif ($l =~ /^([\w\-\(\)\/ ]+):\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($1, $2);

      if ($state eq 'std')
      {
        $metalun_obj->{$kw}= $val;
      }
      elsif ($state eq 'sc')
      {
	if ($kw eq 'LUN Number')
	{ # a new stripe component
          $sc= { $kw => $val };
	  $cc->{'stripe components'}->[$sc_idx++]= $sc;

	  $metalun_obj->{'component'}->{$val}= $sc;
	}
	else
	{
	  $sc->{$kw}= $val;
	}
      }
    }
    else
    {
      print __LINE__, " >>> '$l'\n";
    }
  }

  ('metalun', $label, $metalun_obj);
}

sub Summary1
{
  my $obj= shift;

  my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $name)=
     map { $obj->{$_} }
     ( 'LUN', 'RAIDGroup ID', 'RAID Type', 'Offset', 'LUN Capacity(Megabytes)', 'IS Private',
       'disk_count', 'Name',
     );

  ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $name);
}

sub Summary_Header
{
  shift;
  my $sp= shift;

  print ' ' x$sp;
  printf ("%3s %4s %6s %7s %4s %4s %7s %s\n", 'RG', 'LUN', 'Type', 'capa', 'Disks', 'priv', 'State', 'Name');
}

sub Summary
{
  my $obj= shift;
  my $sp= shift;

  my ($lun, $rg_id, $rt, $off, $mb, $priv, $n_disk, $state, $name)=
     map { $obj->{$_} }
     ( 'LUN', 'RAIDGroup ID', 'RAID Type', 'Offset', 'LUN Capacity(Megabytes)', 'Is Private',
       'disk_count', 'State', 'Name',
     );

  $rt= 'HS' if ($rt eq 'Hot Spare'); # well, I don't expect to see spare MetaLUNs...
  my $gb= $mb / 1024;

  print ' ' x$sp;
  printf ("%3d %4d %6s %7.2f %5d %4s %7s %s\n", $rg_id, $lun, $rt, $gb, $n_disk, $priv, $state, $name);
}

sub Details
{
  my $obj= shift;

  $obj->Summary_Header ();
  $obj->Summary ();
}

1;

