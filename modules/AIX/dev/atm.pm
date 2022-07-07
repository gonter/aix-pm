#
# FILE AIX/dev/atm.pm
#
# encapsulation for AIX ATM device information
# packages:
# + AIX::dev::atm::stats    run time statistics
# + AIX::dev::atm::attr     boot time attributes
# + AIX::dev::atm           container class
#
# written:       2000-01-15
# latest update: 2000-03-08 15:29:00
# $Id: atm.pm,v 1.2 2000/03/08 21:11:19 gonter Exp $
#

use strict;

# ----------------------------------------------------------------------------
package AIX::dev::atm::stats;

# translation for device statistics into object attributes
my %Turboways_Stats=
(
 'Packets Dropped - No small DMA buffer' => '',
 'Packets Dropped - No medium DMA buffer' => '',
 'Packets Dropped - No large DMA buffer' => '',
 'Receive Attempted - No Adapter Receive Buffer' => '',
 'Transmit Attempted - No small DMA buffer' => '',
 'Transmit Attempted - No medium DMA buffer' => '',
 'Transmit Attempted - No large DMA buffer' => '',
 'Transmit Attempted - No MTB DMA buffer' => '',
 'Transmit Aborted - No Adapter Transmit Buffer' => '',
 'Max Hardware transmit queue length' => '',
 'Small Mbuf in Use'      => 'used_sml_bufs',
 'Medium Mbuf in Use'     => 'used_med_bufs',
 'Large Mbuf in Use'      => 'used_lrg_bufs',
 'Huge Mbuf in Use'       => 'used_hug_bufs',
 'MTB Mbuf in Use'        => 'used_spec_bufs',
 'Max Small Mbuf in Use'  => 'max_sml_bufs',
 'Max Medium Mbuf in Use' => 'max_med_bufs',
 'Max Large Mbuf in Use'  => 'max_lrg_bufs',
 'Max Huge Mbuf in Use'   => 'max_hug_bufs',
 'Max MTB Mbuf in Use'    => 'max_spec_bufs',
 'Small Mbuf overflow'    => 'err_sml_bufs',
 'Medium Mbuf overflow'   => 'err_med_bufs',
 'Large Mbuf overflow'    => 'err_lrg_bufs',
 'Huge Mbuf overflow'     => 'err_hug_bufs',
 'MTB Mbuf overflow'      => 'err_spec_bufs'
);

sub new
{
  my $class= shift;
  my $dev= shift;
  my %par= @_;

  # print ">> new stats $dev\n";
  my $stat_driver= {};
  my $res=
  {
    'device' => $dev,
    'time' => time,
    'general' => {},   # general statistics
    'xmit' => {},      # transfer statistics
    'recv' => {},      # receive statistics
    'driver' => $stat_driver,    # driver dependant statistics
  };

  my $section= '?';
  my $in;

  if ($par{'is_file'})
  {
    $in= $dev;
  }
  else
  {
    $in= "/usr/ucb/netstat -v $dev|";
  }

  open (NETSTAT, $in) || die;

  while (<NETSTAT>)
  {
    chop;
    if (/^[\- ]+$/) { next; }
    elsif (/Turboways ATM Adapter Specific Statistics:/)
    {
      $section= 'Turboways';
      next;
    }

    if ($section eq 'Turboways')
    {
      my ($desc, $value)= split (/: */);
      # print "desc='$desc' value='$value'\n";
      # print " '$desc' => '',\n";
      my $tlt= $Turboways_Stats{$desc};
      $stat_driver->{$tlt}= $value if ($tlt);
    }
  }
  close (NETSTAT);

  bless $res;
}

# ----------------------------------------------------------------------------
package AIX::dev::atm::attr;
### sub get_acceptable_range
### {
###   my $av= shift;
###   my $a;
### 
###   foreach $a (@$av)
###   {
###     $a->{range}= `lsattr -R -l atm0 -R -a $a->{attribute}`;
###   }
### }

sub log_watch
{
  my $obj= shift;
  my @keys= @_;
  my $attr= $obj->{LOG_WATCH};

  my $a;
  foreach $a (@keys)
  {
    $attr->{$a}= 1;
  }
}

sub print_attr
{
  my $obj= shift;
  my @keys= @_;

  my $attr= $obj->{AV_hash};
  @keys= sort keys %$attr if ($#keys == -1);

  my $a;
  foreach $a (@keys)
  {
    my $av= $attr->{$a};
    printf ("%-16s %-10s %5s %s\n",
            map { $av->{$_} } qw(attribute value settable description));
  }
}

sub new
{
  my $class= shift;
  my $dev= shift;

  # print ">> new attr $dev\n";
  my @AV;    # attribute values
  my %AV;

  open (LSATTR, "/usr/sbin/lsattr -El $dev|") || die;

  while (<LSATTR>)
  {
    chop;
    # attribute  value  description user_settable
    my ($attribute, $value, @rest)= split;

    my $attr=
    {
      'attribute' => $attribute,
      'value' => $value,
      'settable' => pop (@rest),
      'description' => join (' ', @rest),
    };

    push (@AV, $attr);
    $AV{$attribute}= $attr;
  }

  close (LSATTR);

  my $res=
  {
    'adapter' => $dev,
    'AV_list' => \@AV,
    'AV_hash' => \%AV,
  };

  bless $res;
}

# ----------------------------------------------------------------------------
package AIX::dev::atm;

my @mbufs= qw(hug_bufs lrg_bufs med_bufs sml_bufs spec_bufs);

sub new
{
  my $class= shift;
  my $adapter= shift;
  my $nw_device= shift;
  my $obj=
  {
    'adapter' => $adapter,
    'nw_device' => $nw_device,
  };
  bless $obj;
}

sub attributes
{
  my $obj= shift;
  unless (defined ($obj->{attributes}))
  {
    $obj->{attributes}= new AIX::dev::atm::attr ($obj->{adapter});
  }

  $obj->{attributes};
}

sub statistics
{
  my $obj= shift;
  $obj->{statistics}= new AIX::dev::atm::stats ($obj->{nw_device});
}

sub print_attr
{
  my $obj= shift;
  $obj->{attributes}->print_attr (@_);
}

sub diag_mbuf
{
  my $obj= shift;
  my %arg= @_;
  my $verbose= $arg{'verbose'};

  my $attr= $obj->attributes;
  my $av= $attr->{AV_hash};
  my $stat= $obj->statistics;
  my $sd= $stat->{'driver'};    # driver dependant statistics

  my $idx;

  printf ("%-16s %10s %10s %10s | %10s %5s\n",
          qw(name used alloc max errors diag));
  my $a;
  my @res;       # result set
  my $res= 'ok'; # total results
  foreach $a (@mbufs)
  {
    my $used=      $sd->{"used_$a"};
    my $allocated= $sd->{"max_$a"};
    my $errors=    $sd->{"err_$a"};
    my $max=       $av->{"max_$a"}->{value};

    my $diag= 'ok';
    if ($allocated >= $max)
    {
      $diag= 'full';
      $diag= 'danger' if ($used > ($max * 9/10));
      $diag= 'crash'  if ($used >= $max);
    }

    if ($diag eq 'ok') {} # NOP
    elsif ($diag eq 'crash') { $res= 'crash'; }
    elsif ($diag eq 'danger' && ($res eq 'ok' || $res eq 'full'))
                { $res= 'danger'; }
    elsif ($diag eq 'full' && $res eq 'ok') { $res= 'full'; }

    push (@res, "$a=$diag");

    if ($verbose)
    {
      printf ("%-16s %10ld %10ld %10ld | %10ld %5s\n",
              $a, $used, $allocated, $max, $errors, $diag);
    }
  }

  ($res, @res);
}

1;

