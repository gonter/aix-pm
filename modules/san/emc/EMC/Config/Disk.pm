#
# $Id: Disk.pm,v 1.10 2012/03/08 13:14:03 gonter Exp $
#

use strict;

package EMC::Config::Disk;

=pod

=head1 NAME

  EMC::Config::Disk  -- EMC CLARiiON disk configuration data

=cut

sub new
{
  my $class= shift;

  my $bus= shift;
  my $encl= shift;
  my $disk= shift;

  my $do=
  {
    'bus'  => $bus,
    'encl' => $encl,
    'disk' => $disk,
  };

  bless $do, $class;
  $do;
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

  my $tag= $item->[0];
  return ('invalid', $tag, $item) unless ($tag =~ m#Bus\s+(\d+)\s+Enclosure\s+(\d+)\s+Disk\s+(\d+)(.*)#);

  my ($bus, $encl, $disk, $extra)= ($1, $2, $3, $4);
  if ($extra)
  {
    $extra =~ s/^\s*//;
    ## print __LINE__, " >>>> extra='$extra'\n";
  }
  my $label= join ('_', $bus, $encl, $disk);

  my $do= new EMC::Config::Disk ($bus, $encl, $disk);
  $do->{'label'}= $label;

  my @l= @$item;
  shift (@l);

  foreach my $l (@l)
  {
    if ($l =~ /^([\w ]+):\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($1, $2);
      $val=~ s/\s*$//;
      $do->{$kw}= $val;
    }
    else
    {
      print __LINE__, " >>> '$l'\n";
    }
  }

  ('disk', $label, $do);
}

sub Summary1
{
  my $obj= shift;

  my ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns, $hsr, $pct_busy, $tla_pn)=
     map { $obj->{$_} }
     ( 'bus', 'encl', 'disk', 'Product Id', 'Serial Number', 'State', 'Raid Group ID', 'Capacity',
     'Number of Luns', 'Hot Spare Replacing', 'Prct Busy', 'Clariion TLA Part Number');

  $rg_id= 'none' if ($rg_id eq 'This disk does not belong to a RAIDGroup');

  if ($state eq 'Hot Spare Ready')
  {
    # $state= ($hsr eq 'Inactive') ? 'HS_ready' : 'Replacing';
    $state= 'HS_ready';
  }
  elsif ($state eq 'Enabled' && defined ($hsr) && $hsr ne 'Inactive')
  {
    $state= 'Replacing';
  }

  ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns, $hsr, $pct_busy, $tla_pn);
}

sub Summary_Header
{
  shift;

  printf ("%3s %4s %4s %4s %4s %4s %10s %10s %s\n", 'bus', 'encl', 'disk', 'capa', 'RG', 'LUNs', 'state', 'sn', 'prod');
}

sub Summary
{
  my $obj= shift;

  my $comment;
  my ($bus, $encl, $disk, $prod, $sn, $state, $rg_id, $capacity, $n_luns, $hsr)=
     map { $obj->{$_} }
     ( 'bus', 'encl', 'disk', 'Product Id', 'Serial Number', 'State', 'Raid Group ID', 'Capacity',
     'Number of Luns', 'Hot Spare Replacing');

  $capacity /= 1024;
  if ($state eq 'Hot Spare Ready')
  {
    # $state= ($hsr eq 'Inactive') ? 'HS_ready' : 'Replacing';
    $state= 'HS_ready';
  }
  elsif ($state eq 'Rebuilding' && defined ($hsr) && $hsr ne 'Inactive')
  {
    # $state= 'Replacing';
    $comment .= ' F:'. $hsr;
  }
  elsif ($state eq 'Enabled' && defined ($hsr) && $hsr ne 'Inactive')
  {
    $state= 'Replacing';
    $comment .= ' F:'. $hsr;
  }

  printf ("%3d %4d %4d %4d %4d %4d %10s %10s %s %s\n",
	  $bus, $encl, $disk, $capacity, $rg_id, $n_luns, $state, $sn, $prod, $comment);
}

sub Busy
{
  my $obj= shift;

  my ($bus, $encl, $disk, $rg_id, $n_luns, $rd_rq, $rd_kb, $wr_rq, $wr_kb, $sbc)=
     map { $obj->{$_} }
     ( 'bus', 'encl', 'disk', 'Raid Group ID', 'Number of Luns',
       'Read Requests', 'Kbytes Read', 'Write Requests', 'Kbytes Written', 'Stripe Boundary Crossing',
     );

  ($bus, $encl, $disk, $rg_id, $n_luns, $rd_rq, $rd_kb, $wr_rq, $wr_kb, $sbc);
}

1;

=pod

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

=over
