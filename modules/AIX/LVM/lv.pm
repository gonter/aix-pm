#
# $Id: lv.pm,v 1.7 2010/06/11 19:54:08 gonter Exp $
#

use strict;

package AIX::LVM::lv;

my $LSLV= '/usr/sbin/lslv';

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->set (@_);

  $obj->get_lv_info () if (exists ($obj->{'lv_name'}));

  $obj;
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

sub get_array
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

sub get_hash
{
  my $obj= shift;
  my @par= @_;

  my %res;
  foreach my $par (@par)
  {
    $res{$par}= $obj->{$par};
  }

  (wantarray) ? %res : \%res;
}

*get= *get_array;

sub get_lv_info
{
  my $obj= shift;

  my $lv_name= $obj->{'lv_name'};

  my $cmd= "$LSLV '$lv_name'";
  # print join (' ', '#', __FILE__, __LINE__, $cmd), "\n";
  open (LSLV, $cmd . '|') or die;
  while (<LSLV>)
  {
    chop;
## print __FILE__, ' ', __LINE__, " >> $_\n";
    if (   /(LOGICAL VOLUME):\s+(\S+)\s+(VOLUME GROUP):\s+(\S+)/
        || /(LV IDENTIFIER):\s+(\S+)\s+(PERMISSION):\s+(\S+)/
        || /(VG STATE):\s+(\S+)\s+(LV STATE):\s+(\S+)/
        || /(TYPE):\s+(\S+)\s+(WRITE VERIFY):\s+(\S+)/
        || /(MAX LPs):\s+(\d+)\s+(PP SIZE):\s+(\d+) megabyte\(s\)/
        || /(COPIES):\s+(\d+)\s+(SCHED POLICY):\s+(\S+)/
        || /(LPs):\s+(\d+)\s+(PPs):\s+(\d+)/
        || /(STALE PPs):\s+(\d+)\s+(BB POLICY):\s+(\S+)/
        || /(INTER-POLICY):\s+(\S+)\s+(RELOCATABLE):\s+(\S+)/
        || /(INTRA-POLICY):\s+(\S+)\s+(UPPER BOUND):\s+(\d+)/
        || /(MOUNT POINT):\s+(.+)\s+(LABEL):\s+(.+)/
       )
    {
      my ($an1, $av1, $an2, $av2)= ($1, $2, $3, $4);
      if ($an1 eq '' || $an2 eq '') { print ">>>>>>>>> '$_'\n"; }
      $av1=~ s/\s*$//;
      $av2=~ s/\s*$//;
      $obj->{$an1}= $av1;
      $obj->{$an2}= $av2;
    }
    elsif (   /(PV STATE):\s+(\S+)/
           || /(MIRROR WRITE CONSISTENCY):\s+(\S+)\s+/
           || /(EACH LP COPY ON A SEPARATE PV) \?:\s+(\S+)\s*/
           || /(Serialize IO) \?:\s+(\S+)\s*/
	  )
    {
      my ($an1, $av1)= ($1, $2);
      $obj->{$an1}= $av1;
    }
    else
    { # TODO complain
print __FILE__, ' ', __LINE__, "ATTN: unknown line '$_'\n";
    }
  }
  close (LSLV);

}

=pod

=head2 $lv->get_lp_map ()

retrieve mapping of logical partitions to phyiscal partitions

=cut

sub get_lp_map
{
  my $obj= shift;

  my $lv_name= $obj->{'lv_name'};

  my $cmd= "$LSLV -m '$lv_name'";
print join (' ', '#', __FILE__, __LINE__, $cmd), "\n";

  open (LSLV, $cmd . '|') or die;
  my $l1= <LSLV>;
  my $l2= <LSLV>;
  my @lp_pp_map= ();
  $obj->{'lp_pp_map'}= \@lp_pp_map;
  while (<LSLV>)
  {
    chop;
# print __FILE__, ' ', __LINE__, " >> $_\n";

    # my ($lp, $pp1, $pv1, $pp2, $pv2, $pp3, $pv3)= split (' ');
    my @m= split (' ');
    $lp_pp_map[$m[0]]= \@m;
  }
  close (LSLV);

  \@lp_pp_map;
}

sub get_lv_pv
{
  my $obj= shift;

  my $lv_name= $obj->{'lv_name'};

  my $cmd= "$LSLV -l '$lv_name'";
print join (' ', '#', __FILE__, __LINE__, $cmd), "\n";
  open (LSLV, $cmd . '|') or die;

  my $l1= <LSLV>;
  my $l2= <LSLV>;
  my %pv_distr= ();
  $obj->{'pv_distr'}= \%pv_distr;
  while (<LSLV>)
  {
    chop;
print __FILE__, ' ', __LINE__, " >> $_\n";
    if (my @d= /^((hdisk|hdiskpower)(\d+))\s+(\d+):(\d+):(\d+)\s+(\d+)\%\s+(\d+):(\d+):(\d+):(\d+):(\d+)\s*$/)
    {
      # my ($pv_name, $cp1, $cp2, $cp3, $pct_in_band, $d1, $d2, $d3, $f4, $d5)= ($1, $2, $3, $4, $5, $6, $7 $8, $9, $10, $11, $12);
print __FILE__, ' ', __LINE__, ' >>>> d=(', join (', ', @d), "\n";
      $pv_distr{$d[0]}= \@d;
    }
    else
    {
print __FILE__, ' ', __LINE__, "ATTN: unknown line '$_'\n";
    }
  }
  close (LSLV);
}

1;

__END__

