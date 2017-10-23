# $Id: Config.pm,v 1.7 2012/05/11 09:24:46 gonter Exp $

use strict;

package NetApp::Config::fcp_adapter;

sub get_wwn
{ 
  my $spport_o= shift;
  my $what= shift || 'wwpn';

  $what= 'FC Portname' if ($what eq 'wwpn');
  $what= 'FC Nodename' if ($what eq 'wwnn');
  my ($res)= split (' ', $spport_o->{$what});
  $res;
}

package NetApp::Config::lun;

package NetApp::Config;

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

sub find
{
  my $obj= shift;
  my $section= shift;
  my $name= shift;
  my %par= @_;

  my $r;
  unless (defined ($r= $obj->{$section}->{$name}))
  {
    # create hashes for data of various configuration items
    # and bless as object for some especially interesting items
    $r= $obj->{$section}->{$name}= { $section => $name };

       if ($section eq 'fcp_adapter') { bless ($r, 'NetApp::Config::fcp_adapter') }
    elsif ($section eq 'lun_path')    { bless ($r, 'NetApp::Config::lun') }
  }

  foreach my $p (keys %par)
  {
    $r->{$p}= $par{$p};
  }

  $r;
}

sub parse_lines
{
  my $obj= shift;
  my $lines= shift;

  # print "obj=[$obj] lines=[$lines]\n";

  my $section= undef;
  my $x1_obj= undef;
  my $x2_obj= undef;
  my $x3_obj= undef;

  foreach my $line (@$lines)
  {
    print ">> [$line]\n";

    if ($line =~ m#(.+)> +(.+)#)
    {
      my ($prompt, $cmd)= ($1, $2);
      my @cmd= split (' ', $cmd);
      $section= join (' ', @cmd);
      print ">>> [$section]\n";
    }
    elsif ($section eq 'fcp show adapter')
    {
      if ($line =~ m#([^:]+):\s+(.+)#)
      {
	my ($an, $av)= ($1, $2);
        $x1_obj= $obj->find ('fcp_adapter', $av) if ($an eq 'Slot');

	$x1_obj->{$an}= $av;
      }
      elsif ($line eq '') # NOP
      {
	$x1_obj= undef;
      }
      else
      {
	goto UK1;
      }
    }
    elsif ($section eq 'fcp show initiator')
    {
      if ($line =~ m#Initiators connected on adapter (.+):#)
      {
	my $slot= $1;
        $x1_obj= $obj->find ('fcp_adapter', $slot, 'initiators' => ($x2_obj= []));
      }
      elsif ($line =~ /^\s+None connected/
	     || $line =~ m#Portname\s+Group# || $line =~ m#^-+\s+-+$# # just table headings
	    ) {} # NOP
      elsif ($line eq '') # NOP, end of initiator list for one slot
      {
	$x1_obj= $x2_obj= $x3_obj= undef;
      }
      elsif ($line =~ m#^\s+WWPN Alias\(es\):\s+(.+)#)
      {
        my @wwpn_aliases= split (/, */, $1);
	foreach my $wwpn_alias (@wwpn_aliases)
	{
	  $x3_obj->{'wwpn_aliases'}->{$wwpn_alias}++;
        }
      }
      elsif ($line =~ m#^([\dA-Fa-f:]{23})\s+(\S*.*)#)
      {
	my ($wwpn, $group)= ($1, $2);
	push (@$x2_obj, $x3_obj= {'wwpn' => $wwpn, 'group' => $group});
      }
      else
      {
	goto UK1;
      }
    }
    elsif ($section eq 'fcp wwpn-alias show')
    {
      my ($wwpn, $alias)= split (' ', $line);
      if ($wwpn eq 'WWPN' || $wwpn eq '----') {}
      elsif ($wwpn =~ m#[\da-fA-F:]+#)
      {
        $x1_obj= $obj->find ('wwpn', $wwpn, 'alias' => $alias);
        $x1_obj= $obj->find ('alias' => $alias, 'wwpn', $wwpn);
      }
    }
    elsif ($section eq 'igroup show')
    {
    }
    elsif ($section eq 'lun show -v')
    {
# print __LINE__, " >>> [", $line, "]\n";

      if ($line =~ m#^\s+(/\S+)\s+(\S+)\s+\((\d+)\)\s+\(([^)]+)\)$#)
      {
	my ($lun_path, $size_h, $size_b, $options)= ($1, $2, $3, $4);
	my @lun_path= split ('/', $lun_path);
	# print "lun_path: ", main::Dumper (\@lun_path);

        $x1_obj= $obj->find ('lun_path', $lun_path,
	  # 'lun_path' => $lun_path,
	  'lun_size' => [ $size_h, $size_b ],
	  '_options' => $options,
	  'vol_name' => $lun_path[2],
          'lun_name' => $lun_path[3]
	  # '_maps'    => [ undef, undef ],
	);

	$obj->{'lun_vol'}->{$lun_path[3]}->{$lun_path[3]}= $lun_path; # create a map of lun names
      }
      elsif ($line =~ m#^\s+([^:]+):\s+(.+)#)
      {
	my ($an, $av)= ($1, $2);
	$av=~ s/\s*$//;
        $x1_obj->{$an}= $av;

	if ($an eq 'Maps')
	{
	  my ($sg, $id)= split ('=', $av);
	  $x1_obj->{'_maps'}= [ $sg, $id ];
	}
	elsif ($an eq 'Occupied Size')
	{
	  if ($av =~ m#(\S+)\s+\((\d+)\)#)
	  {
	    $x1_obj->{'_occupied_size'}= [ $1, $2 ];
	  }
	}
	elsif ($an eq 'Serial#')
	{
          $x2_obj= $obj->find ('lun_serial' => $av, 'lun_path', $x1_obj->{'lun_path'});
	}
      }
      else
      {
	goto UK1;
      }

    }
    else
    {
UK1:
      print "unknown line: section=[$section] [$line]\n";
    }
  }
}

1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

