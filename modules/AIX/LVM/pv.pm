#
# $Id: pv.pm,v 1.5 2011/11/02 18:20:41 gonter Exp $
#

use strict;

package AIX::LVM::pv;

my $LSPV= '/usr/sbin/lspv';

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->set (@_);

  $obj->get_pv_info () if (exists ($obj->{'pv_name'}));

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

sub get_pv_info
{
  my $obj= shift;
  my $pv= $obj->{'pv_name'};

  open (LSPV, "$LSPV '$pv'|") or die;
  while (<LSPV>)
  {
    chop;
## print __FILE__, ' ', __LINE__, " >> $_\n";
    if (/(PHYSICAL VOLUME):\s+(\S+)\s+(VOLUME GROUP):\s+(\S+)/
        || /(PV IDENTIFIER):\s+(\S+)\s+(VG IDENTIFIER)\s+(\S+)/
        || /(STALE PARTITIONS):\s+(\d+)\s+(ALLOCATABLE):\s+(\S+)/
        || /(PP SIZE):\s+(\d+)\s+megabyte\(s\)\s+(LOGICAL VOLUMES):\s+(\d+)/
        || /(TOTAL PPs):\s+(\d+)\s+\(\d+ megabytes\)\s+(VG DESCRIPTORS):\s+(\d+)/
        || /(FREE PPs):\s+(\d+)\s+\(\d+ megabytes\)\s+(HOT SPARE):\s+(\S+)/
        || /(USED PPs):\s+(\d+)\s+\(\d+ megabytes\)\s+(MAX REQUEST):\s+(\S+)/
       )
    {
      my ($an1, $av1, $an2, $av2)= ($1, $2, $3, $4);
      $obj->{$an1}= $av1;
      $obj->{$an2}= $av2;
    }
    elsif (/(PV STATE):\s+(\S+)/
           || /(USED PPs):\s+(\d+)\s+\(\d+ megabytes\)/
           || /^(MIRROR POOL):\s+(.+)/
          )
    {
      my ($an1, $av1)= ($1, $2);
      $obj->{$an1}= $av1;
    }
    elsif (/(FREE DISTRIBUTION|USED DISTRIBUTION):\s+(\d+)\.\.(\d+)\.\.(\d+)\.\.(\d+)\.\.(\d+)/)
    {
      my ($an1, @distribution)= ($1, $2, $3, $4, $5, $6);
      $obj->{$an1}= \@distribution;
    }
    else
    { # TODO complain
print __FILE__, ' ', __LINE__, " ATTN: unknown line $_\n";
    }
  }
  close (LSPV);

}

1;

__END__

