# $Id: PowerPath.pm,v 1.9 2012/03/22 11:22:48 gonter Exp $

=pod

=head1 NAME

EMC::PowerPath  --  handle PowerPath devices

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;

package EMC::PowerPath;

use EMC::PowerPath::Device;

my $powermt= '/usr/sbin/powermt';

my $debug= 1;
my $inject_errors= 0;

sub debug
{
  $debug= shift;
}

sub inject_errors
{
  $inject_errors= shift;
}

sub new
{
  my $class= shift;

  my $obj= {};
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

=pod

=head2 $pp->get_device ('hdiskpower42')

return device object for given pseudo device name

=cut

sub get_device
{
  my $pp_obj= shift;
  my $dev_name= shift;

  my $idx= $pp_obj->{'pseudo_device_names'}->{$dev_name};
  return undef unless (defined ($idx));

  $pp_obj->{'device_list'}->[$idx];
}

sub parse
{
  my $pp_obj= shift;
  my $dev_spec= shift;

  my $cmd= "$powermt display dev='$dev_spec'";
  print join (' ', __FILE__, __LINE__, '>'x$debug, $cmd), "\n" if ($debug > 2);

  my $num_devices= 0;
  my $obj= undef; # current PowerPath device
  open (PP, $cmd . '|') or die;
  my $dev_name;
  while (<PP>)
  {
    chop;
    print join (' ', __FILE__, __LINE__, '>'x$debug, $_), "\n" if ($debug > 2);
    if ($inject_errors)
    {
      if (/SP B1/)
      {
	s/active/unlic/;
      }
    }

    if (/Pseudo name=(.+)/)
    {
      $dev_name= $1;
      $obj= new EMC::PowerPath::Device ($dev_name);
      push (@{$pp_obj->{'device_list'}}, $obj);
      $pp_obj->{'pseudo_device_names'}->{$dev_name}= $#{$pp_obj->{'device_list'}};
      $num_devices++;
    }
    elsif (/CLARiiON ID=(\S+)\s+\[([^\]]+)\]/) { $obj->{'CLARiiON ID'}= $1; $obj->{'SG_name'}= $2; }
    elsif (/Logical device ID=(\S+)\s+\[([^\]]+)\]/) { $obj->{'logical_dev_id'}= $1; $obj->{'lun_name'}= $2; }
    elsif (/state=(.+); policy=(.+); priority=(.+); queued-IOs=(.+)/)
    {
      $obj->{'state'}= $1;
      $obj->{'policy'}= $2;
      $obj->{'priority'}= $3;
      $obj->{'queued-IOs'}= $4;
    }
    elsif (/Owner: default=(SP [AB]), current=(SP [AB])/)
    {
      $obj->{'default_owner'}= $1;
      $obj->{'current_owner'}= $2;
    }
    elsif (/=======================/
	   || /------------- Host ---------/
	   || /### +HW Path     /
	   || /^$/
	   ) { } # NOP
    elsif (/\s+(\d+)\s+(fscsi\d+)\s+(hdisk\d+)\s+(SP [AB]\d)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)/)
    {
      my $path= [ $1, $2, $3, $4, $5, $6, $7, $8 ];
      push (@{$obj->{'paths'}}, $path);
      $pp_obj->{'hdisk'}->{$path->[2]}= $dev_name;
    }
    else
    {
      print join (' ', __FILE__, __LINE__, '>>>', $_), "\n";
    }
  }
  close (PP);

  ## main::print_refs (*STDOUT, "powerpath $dev_spec", $obj);
  $num_devices;
}

sub check_paths
{
  my $obj= shift;
  my $X_san= shift; # configuration data about each storage system

## print __FILE__, ' ', __LINE__, ' X_san: ', main::Dumper ($X_san);
  if (defined ($X_san))
  {
    $X_san->{'_checked_'}= []; # XXX collected data from each pseudo device
  }

  my $err_cnt= 0;
  my @summary;
  foreach my $pp_dev (@{$obj->{'device_list'}})
  {
## print "pp_dev=[$pp_dev]: ", main::Dumper ($pp_dev);
    my ($c1, $n1, $s1)= $pp_dev->check_path ($X_san);
    if ($c1)
    {
      $err_cnt += $c1;
      push (@summary, join (' ', $n1, $s1));
    }
  }

  ($err_cnt, join (', ', @summary));
}

1;

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more details, see http://aix-pm.sourceforge.net/

=over

