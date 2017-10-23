# $Id: Device.pm,v 1.3 2012/03/22 11:22:48 gonter Exp $

=pod

=head1 NAME

EMC::PowerPath::Device  --  handle one PowerPath disk devices

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;

package EMC::PowerPath::Device;

use Data::Dumper;

my $print_diags= 0;

sub new
{
  my $class= shift;
  my $dev_name= shift;

  my $obj= {};
  bless $obj, $class;
  $obj->{'Pseudo name'}= $dev_name;
  $obj;
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

sub check_path
{
  my $obj= shift;
  my $X_san= shift; # currently known configuration data about each storage system

## print __LINE__, " obj= ", Dumper ($obj), "\n";
## print __LINE__, " X_san= ", Dumper ($X_san), "\n";
  my $nm= $obj->{'Pseudo name'};
  my $sernr= $obj->{'CLARiiON ID'};
  my @paths= @{$obj->{'paths'}};

  my @summary;
  my $known_paths;
  if (defined ($X_san) && ref ($X_san) eq 'HASH')
  {
    my $san= $X_san->{$sernr};
    if (defined ($san))
    {
## print __LINE__, " san= ", Dumper ($san), "\n";
      my $paths= $san->{'paths'};
      foreach my $path (@$paths)
      {
## print __LINE__, " path= ", Dumper ($path), "\n";
        $known_paths->{$path->[0]}->{$path->[1]}=
	{
	  'seen' => 'not_seen',
	  'fabric' => $path->[2],
	  'state' => '?',
	  'mode' => '?',
	};
      }
    }
    else
    {
      push (@summary, "storage system '$sernr' not found in configuration data\n");
    }
push (@{$X_san->{'_checked_'}}, [ $sernr, $nm, $known_paths, \@summary ]); # XXX record path data for root cause analysis
  }

  my $err_cnt= 0;
  foreach my $path (@paths)
  {
## print __LINE__, " path= ", Dumper ($path), "\n";
# main::print_refs (*STDOUT, "check_path path", $path);
    my ($x1, $fscsi, $x2, $sp_port, $mode, $state)= @$path;

    $known_paths->{$fscsi}->{$sp_port}->{'seen'}= 'seen';
    $known_paths->{$fscsi}->{$sp_port}->{'mode'}= $mode;
    $known_paths->{$fscsi}->{$sp_port}->{'state'}= $state;
  }

## print __LINE__, " known_paths= ", Dumper ($known_paths), "\n";
  foreach my $fscsi (sort keys %$known_paths)
  {
    my $p1= $known_paths->{$fscsi};
    foreach my $sp_port (sort keys %$p1)
    {
      my $p2= $p1->{$sp_port};

      my ($mode, $state, $seen, $fabric)= map { $p2->{$_} } qw(mode state seen fabric);
      unless (defined ($fabric))
      { # The name of the fabric is handed in via X_san (currently known configuration),
	# so if X_san is defined and fabric is not defined, whe have a path which is
	# not in the currently known configuration.  We should report this ...
        $p2->{'fabric'}= $fabric= (defined ($X_san)) ? 'not_defined' : 'unknown';
      }

      unless ($mode eq 'active' && $state eq 'alive' && $seen eq 'seen' && $fabric ne 'not_defined')
      {
        ## print join (' ', $nm, @$path), "\n" if ($debug_level > 1);
        push (@summary, $fscsi, $sp_port, $mode, $state, $seen, $fabric);
        $err_cnt++;
      }
    }
  }

  if ($print_diags && $err_cnt)
  {
    print "$nm $err_cnt problem", ($err_cnt == 1) ? '' : 's', ": ", join (' ', @summary), "\n";;
  }

  ($err_cnt, $nm, join (' ', @summary));
}

1;

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more details, see http://aix-pm.sourceforge.net/

=over

