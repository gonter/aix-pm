#
# $Id: vg.pm,v 1.13 2010/06/11 19:54:08 gonter Exp $
#

=pod

=head1 NAME

AIX::LVM::vg  --  AIX LVM volume group

=head1 SYNOPSIS

  my $rootvg= new $AIX::LVM::VG ('vg_name' => 'rootvg');

=cut

use strict;

package AIX::LVM::vg;

my $VERSTION= 0.10;

use AIX::LVM::pv;
use AIX::LVM::lv;

my $LSVG= '/usr/sbin/lsvg';
my $LMIGRATEPP= '/usr/sbin/lmigratepp';
my $debug_level= 0;

sub new
{
  my $class= shift;

  my $obj=
  {
    '_lv_' => {}, # each LV's object
    '_pv_' => {}, # each PV's object
    'lv'   => {}, # each LV's mapping from LP to copies on up to three PPs
    'pv'   => {}, # each PV's mapping of a LV's PP
    'lv_pv' => {}, # count of a LV's PPs on it's PVs
  };
  bless $obj, $class;

  $obj->set (@_);

  $obj->get_vg_info () if (exists ($obj->{'vg_name'}));

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

    $debug_level= $par{$par} if ($par eq 'debug_level');
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

sub get_vg_info
{
  my $obj= shift;

  my $vg_name= $obj->{'vg_name'};

  my $cmd= "$LSVG '$vg_name'";
  print '# ', __FILE__, ' ', __LINE__, ' ', $cmd, "\n";
  open (LSVG, $cmd . '|') or die;
  while (<LSVG>)
  {
    chop;
## print __LINE__, " >> $_\n";

    if (   /(VOLUME GROUP):\s+(\S+)\s+(VG IDENTIFIER):\s+(\S+)/
        || /(VG STATE):\s+(\S+)\s+(PP SIZE):\s+(\d+) megabyte\(s\)/
        || /(VG PERMISSION):\s+(\S+)\s+(TOTAL PPs):\s+(\d+) \(\d+ megabytes\)/
        || /(MAX LVs):\s+(\S+)\s+(FREE PPs):\s+(\d+) \(\d+ megabytes\)/
        || /(LVs):\s+(\d+)\s+(USED PPs):\s+(\d+) \(\d+ megabytes\)/
        || /(OPEN LVs):\s+(\d+)\s+(QUORUM):\s+(\d+)/
        || /(TOTAL PVs):\s+(\d+)\s+(VG DESCRIPTORS):\s+(\d+)/
        || /(STALE PVs):\s+(\d+)\s+(STALE PPs):\s+(\d+)/
        || /(ACTIVE PVs):\s+(\d+)\s+(AUTO ON):\s+(\S+)/
        || /(MAX PPs per PV):\s+(\d+)\s+(MAX PVs):\s+(\d+)/
        || /(LTG size) \(Dynamic\):\s+(\d+) kilobyte\(s\)\s+(AUTO SYNC):\s+(\S+)/
        || /(LTG size):\s+(\d+) kilobyte\(s\)\s+(AUTO SYNC):\s+(\S+)/
        || /(HOT SPARE):\s+(\S+)\s+(BB POLICY):\s+(\S+)/
       )
    {
      $obj->{$1}= $2;
      $obj->{$3}= $4;
    }
    elsif (/MAX PPs per VG:\s+(\d+)\s+/)
    {
      $obj->{$1}= $2;
    }
    else
    {
      print "unknown line in vg_info: '$_'\n";
    }
  }
  close (LSVG);

}

=pod

=head2 $vg->get_lp2pp_map ();

retrieve table that maps each LV's LP to particular PPs on PVs.

NOTE: this was get_lvpp_map () before which is not appropriately named

=head3 LP to PP map

  lp pp map code:
  0 .. free, pars: [ 0 ]
  1 .. used by lv, pars: [ 1, lp_name, lp_num, copy ]
  2 .. used as migration target [ 2, lp_name ]
  3 .. used as migration source, can be reused, [ 3, lp_name, lp_num, copy ]
  9 .. RESERVED, pars: [ 9, RESERVED, num ]

=cut

sub get_lp2pp_map
{
  my $obj= shift;

  my $vg_name= $obj->{'vg_name'};

  my $cmd= "$LSVG -M '$vg_name'";
  print '# ', __FILE__, ' ', __LINE__, ' ', $cmd, "\n";
  open (LSVG, $cmd . '|') or die;

  my $pv= {};
  my $lv= {};
  my $lv_pv= {};    # number of pps on each pv per lv
  my $pv_free= {};  # number of free pps on each pv
  my $pv_used= {};  # number of used pps on each pv
  my $pv_total= {}; # number of pps on each pv

  while (<LSVG>)
  {
    chop;
## print __LINE__, " >> $_\n";
    if ($_ eq $vg_name || $_ eq '') { } # just the vg name again
    elsif (/(\S+):(\d+)-(\d+)$/)
    { # free partition range
      my ($hdisk, $free_pp_start, $free_pp_end)= ($1, $2, $3);

      my $hdx= $pv->{$hdisk};
      $hdx= $pv->{$hdisk}= [] unless (defined ($hdx));

      my $cnt= 0;
      foreach my $free_pp ($free_pp_start .. $free_pp_end)
      {
        $hdx->[$free_pp]= [ 0 ];
	$cnt++;
      }
      $pv_free->{$hdisk} += $cnt;
      $pv_total->{$hdisk} += $cnt;
    }
    elsif (/(\S+):(\d+)$/)
    { # single free partition
      my ($hdisk, $free_pp)= ($1, $2);
      $pv->{$hdisk}->[$free_pp]= [ 0 ];
      $pv_free->{$hdisk}++;
      $pv_total->{$hdisk}++;
    }
    elsif (/(\S+):(\d+)\s+(RESERVED):(\d+)\s*$/)
    { # TODO, that's something bad...
      my ($hdisk, $pp, $bad, $lp)= ($1, $2, $3, $4);
      $pv->{$hdisk}->[$pp]= [ 9, $bad, $lp ];
      $pv_used->{$hdisk}++;
      $pv_total->{$hdisk}++;
    }
    elsif (/(\S+):(\d+)\s+(\S+):(\d+):(\d)\s*$/)   # lp with multiple copies
    {
      my ($hdisk, $pp, $lv_name, $lp, $cp)= ($1, $2, $3, $4, $5);

      $pv->{$hdisk}->[$pp]= [ 1, $lv_name, $lp, $cp ];
      $lv->{$lv_name}->[$lp]->[$cp]= [ $hdisk, $pp ];
      $lv_pv->{$lv_name}->{$hdisk}++;
      $pv_used->{$hdisk}++;
      $pv_total->{$hdisk}++;
    }
    elsif (/(\S+):(\d+)\s+(\S+):(\d+)\s*$/)  # lp without copy
    {
      my ($hdisk, $pp, $lv_name, $lp)= ($1, $2, $3, $4);

      $pv->{$hdisk}->[$pp]= [ 1, $lv_name, $lp, 1 ];  # declare as first copy
      $lv->{$lv_name}->[$lp]->[1]= [ $hdisk, $pp ];
      $lv_pv->{$lv_name}->{$hdisk}++;
      $pv_used->{$hdisk}++;
      $pv_total->{$hdisk}++;
    }
    else
    {
      print __FILE__, ' ', __LINE__, " unknown vg map line: '$_'\n";
    }

  }
  close (LSVG);

  $obj->{'pv'}= $pv;
  $obj->{'lv'}= $lv;
  $obj->{'lv_pv'}= $lv_pv;
  $obj->{'pv_free'}= $pv_free;
  $obj->{'pv_used'}= $pv_used;
  $obj->{'pv_total'}= $pv_total;
  $obj->{'lvpp_mapped'}= 1; # flag that indicates that mapping table was fetched and processed

  1;
}

=pod

=head2 $vg->get_pv_names ();

return list of physical volume names that belong to that vg

=cut

sub get_pv_names
{
  my $vg_obj= shift;

# print __FILE__, ' ', __LINE__, "\n";
  $vg_obj->get_lp2pp_map () unless ($vg_obj->{'lvpp_mapped'});

# print __FILE__, ' ', __LINE__, "\n";
  return undef unless (exists ($vg_obj->{'pv'}));

  my @pv_names= keys %{$vg_obj->{'pv'}};
  foreach my $pv_name (@pv_names)
  {
# print join (' ', __FILE__, __LINE__, 'pv_name:', $pv_name), "\n";
    my $pv= $vg_obj->get_pv ($pv_name);
  }

  (wantarray) ? @pv_names : \@pv_names;
}

=pod

=head2 $vg->get_pv ($pv_name);

return object that represents a physical volume

=cut

sub get_pv
{
  my $vg_obj= shift;
  my $pv_name= shift;

  return $vg_obj->{'_pv_'}->{$pv_name} if (exists ($vg_obj->{'_pv_'}->{$pv_name}));

  my $pv_obj= new AIX::LVM::pv ('pv_name' => $pv_name);
  return undef unless (defined ($pv_obj));

  $vg_obj->{'_pv_'}->{$pv_name}= $pv_obj;
  $pv_obj;
}

=pod

=head2 $vg->get_lv_names ();

return list of logical volume names that belong to that vg

=cut

sub get_lv_names
{
  my $vg_obj= shift;

# print __FILE__, ' ', __LINE__, "\n";
  $vg_obj->get_lp2pp_map () unless ($vg_obj->{'lvpp_mapped'});

  foreach my $lv_name (keys %{$vg_obj->{'lv_pv'}})
  {
# print join (' ', '#', __FILE__, __LINE__, 'lv_name:', $lv_name), "\n";
    my $lv= $vg_obj->get_lv ($lv_name);
  }

  return undef unless (exists ($vg_obj->{'_lv_'}));
  my @lv_names= keys %{$vg_obj->{'_lv_'}};

  (wantarray) ? @lv_names : \@lv_names;
}

=pod

=head2 $vg->get_lv ($lv_name);

return object that represents a logical volume

=cut

sub get_lv
{
  my $vg_obj= shift;
  my $lv_name= shift;

  return $vg_obj->{'_lv_'}->{$lv_name} if (exists ($vg_obj->{'_lv_'}->{$lv_name}));

  my $lv_obj= new AIX::LVM::lv ('lv_name' => $lv_name);
  return undef unless (defined ($lv_obj));

  $vg_obj->{'_lv_'}->{$lv_name}= $lv_obj;
  $lv_obj;
}

=pod

=head2 $vg->find_bad_copies ()

=cut

sub find_bad_copies
{
  my $obj= shift;

  my $lv= $obj->{'lv'};

  my $lv_pv= $obj->{'lv_pv'};
  my $pv= $obj->{'pv'};
  my $pv_free= $obj->{'pv_free'};

  my ($VG_ID)= $obj->get ('VG IDENTIFIER');

  foreach my $lv_name (sort keys %$lv)
  {
    ## print __LINE__, " lv_name='$lv_name'\n";
    my ($cnt, $res)= &_find_lv_bad_copies ($lv_name, $lv->{$lv_name});

    if ($cnt)
    {
      foreach my $lp (sort {$a <=> $b} keys %$res)
      {
        my $case_p= $res->{$lp};
        my $case= $case_p->[0];

        my $lv_obj= $obj->get_lv ($lv_name);
	my ($lv_id)= $lv_obj->get ('LV IDENTIFIER');

        print "move $lv_name $lv_id $lp $case\n";

	if ($case eq 'c1c2')
	{
	  my $source_pv= $case_p->[2]->[0];
	  my $source_pp= $case_p->[2]->[1];

	  my ($target_pv, $target_pp)= &get_migration_target ($lv_name, $lv_pv->{$lv_name}, $pv, $pv_free, { $source_pv => 1 } );
	  unless (defined ($target_pv))
	  {
	    print "ATTN: no target found!\n";
	    next;
	  }

	  my $source_pv_obj= $obj->get_pv ($source_pv);
	  my $target_pv_obj= $obj->get_pv ($target_pv);
	  my ($source_pv_id)= $source_pv_obj->get ('PV IDENTIFIER');
	  my ($target_pv_id)= $target_pv_obj->get ('PV IDENTIFIER');

	  print "possible target: $target_pv $target_pp $target_pv_id\n";
## print join (' ', %$target_pv_obj), "\n";
	  print "         source: $source_pv $source_pp $source_pv_id\n";
## print join (' ', %$source_pv_obj), "\n";
	  my $cmd= "$LMIGRATEPP -g $VG_ID -p $source_pv_id -n $source_pp -P $target_pv_id -N $target_pp";
	  print $cmd, "\n";
	}
	else
	{
	  print "ATTN: cant handle case $case, not yet implemented!\n"; # TODO
	}
      }
    }
  }
}

sub get_lp_stats
{
  my $obj= shift;
  my $bad_configs= shift;

  my $lv= $obj->{'lv'};

  my %t_res= ();
  my $t_cnt= 0;
  foreach my $lv_name (sort keys %$lv)
  {
    ## print __LINE__, " lv_name='$lv_name'\n";
    my ($cnt, $res)= $obj->get_lp_lv_stats ($lv_name, $lv->{$lv_name}, $bad_configs);
    ## main::print_refs (*STDOUT, $lv_name . " mirror configuration", $res);

    # summarize counter for each returned PV configuration into total counter
    $t_cnt += $cnt;
    foreach my $pv_conf (keys %$res)
    {
      $t_res{$pv_conf} += $res->{$pv_conf};
    }
  }

  ## main::print_refs (*STDOUT, $obj->{'vg_name'} . " mirror configuration", \%t_res);

  ($t_cnt, \%t_res);
}

sub get_lp_lv_stats
{
  my $obj= shift;
  my $lv_name= shift;
  my $lvp= shift;
  my $bad_configs= shift;

  my $num_lp= $#$lvp;

  my $lv_pv= $obj->{'lv_pv'};
  my $pv= $obj->{'pv'};
  my $pv_free= $obj->{'pv_free'};
  my ($VG_ID)= $obj->get ('VG IDENTIFIER');

  my $cnt= 0;
  my $result= {};
  print "get_lp_lv_stats: lv_name='$lv_name' num_lp='$num_lp'\n" if ($debug_level > 1);
  for (my $lp= 1; $lp <= $num_lp; $lp++)
  {
    my $lvpp= $lvp->[$lp];
    next unless ($#$lvpp > 1);

    my @cn;
    my $c1= $lvpp->[1]; push (@cn, $c1->[0]);
    my $c2= $lvpp->[2]; push (@cn, $c2->[0]) if (defined ($c2));
    my $c3= $lvpp->[3]; push (@cn, $c3->[0]) if (defined ($c3));

    my $cn= join (':', @cn);
    $cnt++;
    $result->{$cn}++;

    if (defined ($bad_configs) && exists ($bad_configs->{$cn}))
    {
      my $bcrp= $bad_configs->{$cn}; # bad config resolution plan
      my $source_pv= $bcrp->[0];
      my $not_target_pv= $bcrp->[1];

      my $source_pp= ($c1->[0] eq $source_pv) ? $c1->[1] : $c2->[1];
      print join (' ', 'bad configuration:', $lv_name, $lp, $c1->[0], $c1->[1], $c2->[0], $c2->[1]), "\n";

      # BEGIN copy/edit from above
      my ($target_pv, $target_pp)= &get_migration_target ($lv_name, $lv_pv->{$lv_name}, $pv, $pv_free, $not_target_pv);

	  unless (defined ($target_pv))
	  {
	    print "ATTN: no target found!\n";
	    next;
	  }

	  my $source_pv_obj= $obj->get_pv ($source_pv);
	  my $target_pv_obj= $obj->get_pv ($target_pv);
	  my ($source_pv_id)= $source_pv_obj->get ('PV IDENTIFIER');
	  my ($target_pv_id)= $target_pv_obj->get ('PV IDENTIFIER');

	  print "possible target: $target_pv $target_pp $target_pv_id\n";
## print join (' ', %$target_pv_obj), "\n";
	  print "         source: $source_pv $source_pp $source_pv_id\n";
## print join (' ', %$source_pv_obj), "\n";
	  my $cmd= "$LMIGRATEPP -g $VG_ID -p $source_pv_id -n $source_pp -P $target_pv_id -N $target_pp";
	  print $cmd, "\n";

      # END copy/edit from above
    }
  }

  ($cnt, $result);
}

sub get_free_pp_list
{
  my $vg= shift;
  my @pv_names= @_; # do not sort this list

  unless (@pv_names)
  {
    die "specify list of PVs";

    # TODO retreive list of PVs in VG if not already done
    @pv_names= sort keys %{$vg->{'_pv_'}};
  }

  my %pv_done= ();
  my @res= ();
  foreach my $pv_name (@pv_names)
  {
    next if ($pv_done{$pv_name});
    $pv_done{$pv_name}++;

    my @r= $vg->get_free_pp_list_pv ($pv_name);
    push (@res, @r);
  }

  @res;
}

sub get_free_pp_list_pv
{
  my $vg= shift;
  my $pv_name= shift;

  print "get_free_pp_list_pv: pv_name='$pv_name'\n";
  my @res= ();
  my @pp_list= @{$vg->{'pv'}->{$pv_name}};
  print 'pp_list entries: ', $#pp_list, "\n";
## print 'pp_list: ', main::Dumper (\@pp_list), "\n";
  for (my $i= 1; $i <= $#pp_list; $i++)
  {
    my $pp_p= $pp_list[$i];
## print "pp_list[$i]: ", main::Dumper ($pp_p), "\n";
    next unless (defined ($pp_p));

    if ($pp_p->[0] == 0) # partition is free!
    {
      push (@res, [ $pv_name, $i ]);
    }
  }

  @res;
}

=pod

=head2 internal functions

=head3 _find_lv_bad_copies ($lv_name, $lvp);

Checks if any logic partition (LP) has copies on the same physical
volume (PV).  This condition may occur in rare cases.

=cut

sub _find_lv_bad_copies
{
  my $lv_name= shift;
  my $lvp= shift;

  my $num_lp= $#$lvp;

  my $cnt= 0;
  my $result= {};
  print "find_lv_bad_copies: lv_name='$lv_name' num_lp='$num_lp'\n" if ($debug_level > 1);
  for (my $lp= 1; $lp <= $num_lp; $lp++)
  {
    my $lvpp= $lvp->[$lp];
    next unless ($#$lvpp > 1);

    my $c1= $lvpp->[1];
    my $c2= $lvpp->[2];
    my $c3= $lvpp->[3];

    my $note;
    my $do_print= 0;
    my $case;

    if (defined ($c3))
    { # three copies
      if ($c1->[0] eq $c2->[0] && $c1->[0] eq $c3->[0])
      { # all three copies on same pv!
        $case= 'c1c2c3';
      }
      else
      {
	if ($c1->[0] eq $c2->[0]) { $case= 'c1c2x'; } # this is different from c1c2!
        if ($c1->[0] eq $c3->[0]) { $case= 'c1c3'; } 
        if ($c2->[0] eq $c3->[0]) { $case= 'c2c3'; }
      }
    }
    elsif (defined ($c2))
    { # two copies
      if ($c1->[0] eq $c2->[0]) # two copies on the same physical volume
      {
        $case= 'c1c2';
      }
    }
    # else: only one copy

    if (defined ($case))
    {
      $do_print= 1;
      $note= 'mirror on same pv, case='. $case;
      $cnt++;

      $lvpp->[0]= $case;
      $result->{$lp}= $lvpp;
    }

    if ($do_print)
    {
      print "$lv_name $lp :";
      print join (' ', ' c1:', @$c1) if (defined ($c1));
      print join (' ', ' c2:', @$c2) if (defined ($c2));
      print join (' ', ' c3:', @$c3) if (defined ($c3));
      print ' ', $note if (defined ($note));
      print "\n";
    }
  }

  ($cnt, $result);
}

sub get_migration_target
{
  my $lv_name= shift;
  my $lv_pv=   shift;    # list of pvs used for given lv
  my $pv_maps= shift;    # pv to pp maps
  my $pv_free= shift;
  my $pv_skip= shift;

  foreach my $p1 (sort keys %$pv_free)
  {
    my $pp_free= $pv_free->{$p1};
    my $lp_used= $lv_pv->{$p1};

    print "check candidate $p1 $pp_free free, $lp_used by $lv_name\n";
    next unless ($pp_free);  # target pv is not available
    next unless ($lp_used);  # this should always be greater than 0

    next if (exists ($pv_skip->{$p1})); # pv already used for another copy of this lp

    my $pv_map= $pv_maps->{$p1};
    my $last_pv_pp= $#$pv_map;  # the lvpp map contains all the pps
    for my $pp_num (1 .. $last_pv_pp)
    {
      if ($pv_map->[$pp_num]->[0] == 0)
      {
        $pv_map->[$pp_num]= [ 3, $lv_name ]; # we do not know the other pars here
        return ($p1, $pp_num);
      }
    }
  }

  return undef;
}


__END__

=pod

=HEAD1 Author

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=head1 Notes

=over

