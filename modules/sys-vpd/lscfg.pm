# $Id: lscfg.pm,v 1.8 2012/04/22 20:04:12 gonter Exp $

=pod

=head1 NAME

AIX::VPD::lscfg  --  AIX Vital Product Data Configuration

=head1 SYNOPSIS

  my $cfg= new AIX::VPD::lscfg ();
  $cfg->read_lscfg ($filename);
  my ($ty, $snr, $fw)= $cfg->get_array (qw(machine_type serial_number firmware);
  my $cfg_data= $cfg->get_hash (qw(machine_type serial_number firmware));

=head1 DESCRIPTION

process output from AIX command lscfg

=cut

use strict;

package AIX::VPD::lscfg;

use AIX::VPD::fcs;
use Data::Dumper;

my $VERSION= '0.02';

sub new
{
  my $class= shift;

  my $obj=
  {
    'cfg' =>
    { # NOTE: There are three sections in the output of lscfg -pv
      # which relate to devices.

      'DEV' => {
        'loc' => {}, # device names by location code
      },
      'XDEV' => {},
      'YDEV' => {},
    },
    'firmware' => undef,
    'machine_type' => undef,
    'serial_number' => undef,
  };
  bless $obj, $class;

  $obj->set (@_);

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

sub read_lscfg
{
  my $obj= shift;
  my $fnm= shift;
  my $device= shift;

  unless ($fnm)
  {
    $fnm= "lscfg -pv";
    $fnm .= 'l ' . $device if (defined ($device));
    $fnm .= '|';
  }
  open (FI, $fnm) || return undef;
# print __FILE__, ' ', __LINE__, " reading [$fnm]\n";

  $obj->{'_fnm_lscfg_'}= $fnm;
  my $cfg= $obj->{'cfg'};
  my $st= 0;
  my $DEV= undef;
  my $XDEV= undef;
  my $YDEV= undef;

  my $xdev_name= undef;
  my $xdev_field= undef;

  while (<FI>)
  {
    chop;

# print __LINE__, " >>>> st=$st ", $_, "\n";
    if ($st == 0)
    {
      if (/^  PLATFORM SPECIFIC/)
      {
        $DEV= undef;
        $st= 1;
      }
      elsif (/^\s*$/
             || /^INSTALLED RESOURCE LIST WITH VPD$/
             || /^The following resources are installed on your machine.$/
            )
      {
        # $DEV= undef; ... blank lines are not the end of device specific info :-/
      }
      elsif (/^  Model Architecture: (\w+)\s*$/)
      {
        $cfg->{'Architecture'}= $1;
      }
      elsif (/^  Model Implementation: (.+)\s*$/)
      {
        $cfg->{'Implementation'}= $1;
      }
      elsif (/^  ([\w\.]+)\s+(.+)/)
      {
        my ($dev, $x)= ($1, $2);
        $x=~ s/\s*$//;
        my ($loc, $notes);
	if ($dev =~ /^sys\d+/ || $dev =~ /^L2cache\d+/)
	{
	  $loc= '';
	  $notes= $x;
	}
	else
	{
          ($loc, $notes)= split (/  +/, $x);
        }

        # print ">>>>>> dev='$dev' loc='$loc' notes='$notes'\n";

	$DEV=
	{
	  'name' => $dev,
	  'loc' => $loc,
	  'notes' => $notes,
	};

        if ($dev =~ /^ent(\d+)$/)
	{
          push (@{$obj->{'ent'}}, $dev);
        }
        elsif ($dev =~ /^fcs(\d+)$/)
	{
          push (@{$obj->{'fcs'}}, $dev);
	  bless ($DEV, 'AIX::VPD::fcs');
        }
        elsif ($dev =~ /^fscsi(\d+)$/)
	{
          push (@{$obj->{'fscsi'}}, $dev);
	}

        $cfg->{'DEV'}->{$dev}= $DEV;
	push (@{$cfg->{'loc'}->{$loc}}, $dev);
      }
      elsif (defined ($DEV) && /^        (.+)/)
      {
        my $x= $1;
        $x=~ s/\s*$//;
	my ($x1, $x2)= split (/\.\.+/, $x);
	if ($x1 =~ /Device Specific\.\((..)\)/)
	{
	  $DEV->{'DEVICE_SPECIFIC'}= $1;
	}
	$DEV->{$x1}= $x2;
	# print __LINE__, " >>>>>>>> x1='$x1' x2='$x2'\n";
      }
      elsif (defined ($DEV) && /^      (\S.+):/)
      {
        push (@{$DEV->{'EXTRA'}}, $1);
      }
      else
      {
        print __LINE__, " >>>>      ", $_, "\n";
      }
    }
    elsif ($st == 1)
    {
# print __LINE__, " >>>> st=$st ", $_, "\n";
      if (/^\s*$/)
      { # NOP;
      }
      elsif (/^      Physical Location: (.+)/)
      {
        my $loc= $1;
	$XDEV->{'location'}= $loc;
      }
      elsif (/^        (\w.+)/)
      {
        my $x= $1;
	$x=~ s/\s*$//;
	my ($x1, $x2)= split (/\.\.+/, $x);

	$XDEV->{$x1}= $x2;
	$xdev_field= $x1;

        if ($XDEV->{'name'} eq 'System VPD')
	{
	  if ($x1 eq 'Machine/Cabinet Serial No') { $cfg->{'Serial_No'}= $x2; }
          if ($x1 eq 'Machine Type and Model'   # AIX 5.2 ?
              || $x1 eq 'Machine Type/Model')   # AIX 5.3 ?
          {
            $cfg->{'Type_Model'}= $x2;
          }
	}
      }
      elsif (defined ($XDEV) && /^ {36}(\S.+)/)
      {
	my $x= $1;
	$x=~ s/\s*$//;
	$XDEV->{$xdev_field} .= $x;
      }
      elsif (/^      (\w.+):/)
      {
        my $xdev_name= $1;
	$xdev_name=~ s/\s*$//;

	## print __LINE__, " >>>>>>> name='$xdev_name'\n";
        $XDEV=
	{
	  'name' => $xdev_name,
	};
        push (@{$cfg->{'XDEV'}->{$xdev_name}}, $XDEV);
      }
      elsif (defined ($YDEV) && /^    (\w.+):\s+(.+)/)
      {
	$YDEV->{$1}= $2;
      }
      elsif (/^  Name:\s+(.+)/)
      {
	my $ydev_name= $1;
	$XDEV= undef;
	$YDEV= { 'name' => $ydev_name };
        push (@{$cfg->{'YDEV'}->{$ydev_name}}, $YDEV);
      }
      else
      {
        print __LINE__, " >>>> st=$st ", $_, "\n";
      }
    }

  }
  close (FI);

  # note: there is a similar check above
  my @S= ('System VPD', 'System');
  my $X= $cfg->{'XDEV'};
  S: foreach my $s (@S)
  {
    if (exists ($X->{$s}))
    {
      my $vpd= $X->{$s}->[0];
      my ($mtype, $mtype2, $sernr)= map { $vpd->{$_} } ('Machine Type and Model', 'Machine Type/Model', 'Machine/Cabinet Serial No');
      $obj->{'machine_type'}= $mtype || $mtype2;
      $obj->{'serial_number'}= $sernr;
      last S;
    }
  }

  my $firmware= $cfg->{'YDEV'}->{'openprom'}->[0];
  $obj->{'firmware'}= $firmware->{'Model'};

  # match fcs to fscsi devices
  if (exists ($obj->{'fcs'}))
  {
    foreach my $fcs (@{$obj->{'fcs'}})
    {
      my $d_fcs= $cfg->{'DEV'}->{$fcs};
      my $loc= $d_fcs->{'loc'};
      ## print __LINE__, " fcs='$fcs' loc='$loc'\n";
      ## print "d_fcs ", Dumper ($d_fcs), "\n";
      my $same_loc= $cfg->{'loc'}->{$loc};

      if (defined ($same_loc) && ref ($same_loc) eq 'ARRAY')
      {
        foreach my $d (@$same_loc)
        {
	  ## print __LINE__, " at loc='$loc' d='$d'\n";

	  if ($d =~ /^fcs/) {} # NOP
	  elsif ($d =~ /^(fscsi|fcnet)/)
	  {
	    my $d_fX= $cfg->{'DEV'}->{$d};
	    push (@{$d_fcs->{'used_by'}}, $d);
	    $d_fX->{'fcs'}= $fcs;
	  }
	  else {} # WARNING, TODO: maybe something new appears
        }
      }
    }
  }

  $cfg;
}

*read_cfg= *read_lscfg;

sub read_lsdev_C
{
  my $cfg= shift;
  my $fnm= shift;

  open (FI, $fnm) || return undef;

  $cfg->{'_fnm_lsdev_C_'}= $fnm;
  my $dev= $cfg->{'dev'}= {};
  my $cnt= 0;

  while (<FI>)
  {
    chop;

    if (/^(\S+)\s+(Available|Defined)\s([\w\-,]+)\s+(.+)/)
    {
      my ($dev_name, $state, $loc, $desc)= ($1, $2, $3, $4);
      $dev->{$dev_name}=
      {
	'name' => $dev_name,
	'state' => $state,
	'loc' => $loc,
	'desc' => $desc,
      };
      $cnt++;
    }
    elsif (/^(\S+)\s+(Available|Defined)\s\s+(.+)/)
    {
      my ($dev_name, $state, $desc)= ($1, $2, $3);
      $dev->{$dev_name}=
      {
	'name' => $dev_name,
	'state' => $state,
	'desc' => $desc,
      };
      $cnt++;
    }
    else
    {
      print ">>> unknown lsdev line: '$_'\n";
    }
  }
  close (FI);
  $cnt;
}

sub devices
{
  my $cfg= shift;

  my @r1= keys %{$cfg->{'cfg'}->{'DEV'}};
  ## my @r1x= keys %{$cfg->{'cfg'}->{'XDEV'}};
  ## my @r1y= keys %{$cfg->{'cfg'}->{'YDEV'}};
  my @r2= keys %{$cfg->{'dev'}};

  my %r;
  map { $r{$_} |= 0x01; } @r1;
  map { $r{$_} |= 0x02; } @r2;
  ## map { $r{$_} |= 0x10; } @r1x;
  ## map { $r{$_} |= 0x20; } @r1y;

  (wantarray) ? %r : \%r;
}

sub device
{
  my $cfg= shift;
  my $name= shift;

  ($cfg->{'cfg'}->{'DEV'}->{$name}, $cfg->{'dev'}->{$name});
}

1;

__END__

=head1 BUGS

needs more testing

=head1 REFERENCES

man lscfg

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over
