#
# $Id: RaidGroup.pm,v 1.8 2007/07/10 11:34:58 gonter Exp $
#

use strict;

package EMC::Config::RaidGroup;

=pod

=head1 NAME

  EMC::Config::RaidGroup   -- Configuration data of a EMC RaidGroup

=head1 SYNOPSIS

  $rg= new EMC::Config::RaidGroup ($raidgroup_id);

=cut

use EMC::Config::LUN;

my $MB= 1024*1024;
my $GB= 1024*1024*1024;

my $BLOCK_SIZE= 512;
my %list_kw= map { $_ => 1 } ('RaidGroup State', 'List of disks');

sub new
{
  my $class= shift;

  my $rg_id= shift;

  my $do=
  {
    'rg_id'  => $rg_id,
  };

  bless $do, $class;
  $do;
}

sub mb
{
  my $blocks= shift;
  $blocks * $BLOCK_SIZE / $MB;
}

sub gb
{
  my $blocks= shift;
  $blocks * $BLOCK_SIZE / $GB;
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

=pod

=head2 $conf->analyze ($lines)

Analyze the next block of lines for relevant RaidGroup configuration data.

=cut

sub analyze
{
  my $cl_or_obj= shift;
  my $item= shift;

  # print __LINE__, " cl_or_obj='$cl_or_obj'\n";

  my $tag= $item->[0];
  return ('invalid', $tag, $item) unless ($tag =~ m#RaidGroup ID:\s+(\d+)#);

  my ($rg_id)= ($1);
  # my $label= join ('_', 'RG', $rg_id);
  my $label= $rg_id;

  my $do= new EMC::Config::RaidGroup ($rg_id);

  my @l= @$item;
  shift (@l);
  my $last_kw;

  foreach my $l (@l)
  {
    $l=~ s/\s*$//;

    if ($l =~ /^([\w \(\)\-\/,]+):\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($1, $2);

      if (exists($list_kw{$kw}))
      {
        push (@{$do->{$kw}}, $val);
	$last_kw= $kw;
      }
      else
      {
        $do->{$kw}= $val;
	$last_kw= undef;
      }
    }
    elsif ($last_kw && $l =~ /^\s+(.+)\s*$/)
    {
      push (@{$do->{$last_kw}}, $1);
    }
    else
    {
      # print __LINE__, " >>> '$l'\n";
    }
  }

  ('RaidGroup', $label, $do);
}

=pod

=head2 $rg->Summary1 ()

Retrieves summary data for a given RaidGroup object.

=cut

sub Summary1
{
  my $obj= shift;

  my ($rg_id, $l_disk, $l_luns, $rgt, $dp, $blk_raw, $blk_cap, $blk_free, $blk_free_cont)=
     map { $obj->{$_} }
         (
	   'rg_id', 'List of disks', 'List of luns', 'RaidGroup Type',
	   'disk_prod', 'Raw Capacity (Blocks)', 'Logical Capacity (Blocks)',
           'Free Capacity (Blocks,non-contiguous)',
           'Free contiguous group of unbound segments', # in blocks of 512 byte
         );


  $l_luns= '' if ($l_luns eq 'Not Available');

  my ($c_disk, $c_bus, $c_encl, $comment_disk, @l_disk)= &_disk_info ($l_disk);

  ($rg_id, scalar @l_disk, join (' ', @l_disk), $l_luns, $rgt, $dp, $blk_raw, $blk_cap, $blk_free, $blk_free_cont);
}

=pod

=head2 $conf->Summary_Header ()

Print a header line for configuration summary as text.

=cut

sub Summary_Header
{
  printf ("%3s %9s %5s %3s %4s %4s %7s %7s %s\n",
          'ID', 'Type', 'disks', 'bus', 'encl', 'LUNs', 'Size',
          'Free', 'comments');
}

=pod

=head2 $conf->Summary ($show_luns)

Print one line configuration summary for this RaidGroup.  If $show_luns
is true, summary data for each LUN in this RaidGroup is also printed.

=cut

sub Summary
{
  my $obj= shift;
  my $show_luns= shift;

# print __LINE__, " >>> RaidGroup->Summary $obj\n";
# &main::print_refs (*STDOUT, "obj", $obj);

  my ($rg_id, $l_disk, $l_luns, $rgt, $dp, $cap_logical, $cap_free, $luns)=
     map { $obj->{$_} } ('rg_id', 'List of disks', 'List of luns', 'RaidGroup Type', 'disk_prods',
                         'Logical Capacity (Blocks)', 'Free Capacity (Blocks,non-contiguous)', 'lun');

  my $gb_logical= &gb ($cap_logical);
  my $gb_free= &gb ($cap_free);

  # $rgt= 'spare' if ($rgt eq 'hot_spare');

  $l_luns= '' if ($l_luns eq 'Not Available');

  my @luns= split (' ', $l_luns);
  my $c_luns= scalar @luns;
  my $comment= (defined ($dp)) ? join (' ', %$dp) : 'unknown disks';
  $comment .= ' Luns: ('. $l_luns. ')';

  my ($c_disk, $c_bus, $c_encl, $comment_disk)= &_disk_info ($l_disk);
  $comment .= $comment_disk;

  printf ("%3d %9s %5d %3d %4d %4d %7.2f %7.2f %s\n", $rg_id, $rgt, $c_disk,
    $c_bus, $c_encl, $c_luns, $gb_logical, $gb_free, $comment);

  if ($show_luns)
  {
    Summary_Header EMC::Config::LUN (0);

    foreach my $lun (sort { $a <=> $b } keys %$luns)
    {
      $luns->{$lun}->Summary (0);
    }
    print "\n";
  }
}

# This is just an utilty function to aggregate disk information of a
# RaidGroup, passed as the objects sub-structure.
sub _disk_info
{
  my $l_disk= shift;

  my (%bus, %encl);
  my $c_disk= 0;
  my @l_disk= ();
  foreach my $disk_str (@$l_disk)
  {
    next unless ($disk_str =~ m#Bus\s+(\d+)\s+Enclosure\s+(\d+)\s+Disk\s+(\d+)#);

    my ($bus, $encl, $disk)= ($1, $2, $3);
    push (@l_disk, join ('_', $bus, $encl, $disk));
    $bus{$bus}++;
    $encl{$bus .'_'. $encl}++;

    $c_disk++;
  }
  my $c_bus= keys %bus;
  my $c_encl= keys %encl;

  my $comment;
  $comment .= ' multi_bus' if ($c_bus > 1);
  $comment .= ' multi_encl' if ($c_encl > 1);
  ($c_disk, $c_bus, $c_encl, $comment, @l_disk);
}
1;

__END__

=pod

=head1 BUGS/TODO

There really should be more documentation, as always.

Disk Type for RaidGroup ID 0 is 'Mixed' instead of the real
Disk Product Type.

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

=over
