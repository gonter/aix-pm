#!/usr/local/bin/perl
#
# FILE AIX/Software/Maintenance.pm
#
# written:       1998-05-09
# latest update: 2000-01-30  1:23:51
#
# $Id: Maintenance.pm,v 1.9 2008/10/08 07:31:43 gonter Exp $
#

package AIX::Software::Maintenance;

=pod

=head1 NAME

AIX::Software::Maintenance

=head1 DESCRIPTION

Module for AIX software maintenance

=cut

use strict;

my $VERSION= '0.11';

# --------------------------------------------------------------------------------
sub new
{
  my $class= shift;
  my %more= @_;

  my $obj=
  {
    'packages' => {},
    'hosts' => {},              # host names, value == time stamp
    'host_list' => [],
    'show_uninstalled' => 0,
    'show_unavailable' => 0,
  };

  my $k;
  foreach $k (keys %more)
  {
    $obj->{$k}= $more{$k};
  }

  bless $obj, $class;
}

# --------------------------------------------------------------------------------
sub show_uninstalled
{
  my $obj= shift;
  $obj->{show_uninstalled}= 1;
  # HTML output listing should contain also packages that are
  # not installed anywhere
}

# --------------------------------------------------------------------------------
sub show_unavailable
{
  my $obj= shift;
  $obj->{show_unavailable}= 1;
  # HTML output listing should contain also packages that are
  # not available on any fix media
}

# --------------------------------------------------------------------------------
sub fmt_ts
{
  my $time= shift || time;
  my @ts= localtime ($time);
  sprintf ("%4d-%02d-%02d %2d:%02d:%02d",
           $ts[5]+1900, $ts[4]+1, $ts[3],
           $ts[2], $ts[1], $ts[0]);
}
# --------------------------------------------------------------------------------
sub print_packages
{
  my $obj= shift;
  my $fnm= shift;
  my $pg= shift;

  my $ts= &fmt_ts;

  local (*FO);
  open (FO, ">$fnm") || die;
  print "writing html output to $fnm\n";
  print FO <<EOHTML;
<title>AIX Fixes for $fnm</title>
<h1>AIX Fixes for $fnm</h1>
latest update: $ts
<table border=1>
<tr><th>host<th>timestamp from lslpp -Lc output</tr>
EOHTML

  my $hl= $obj->{hosts};
  foreach (sort keys %$hl)
  {
    print FO '<tr><td>', $_, '<td>', &fmt_ts ($hl->{$_}), "</tr>\n";
  }

  print FO <<EOHTML;
</table>
<hr>
EOHTML


  my $rc= $obj->print_packages_FO (*FO, $pg);
  close (FO);

  $rc;
}

# --------------------------------------------------------------------------------
sub print_packages_FO
{
  my $obj= shift;
  local *F= shift;
  my $pg= shift;

  my $packs= $obj->{packages};
  my (@package_list, @host_list);

  if (defined ($pg))
  {
    @host_list= @{$pg->{host_list}};
    @package_list= @{$pg->{package_list}};
  }
  else
  {
    @host_list= @{$obj->{host_list}};
    @package_list= sort keys %$packs;
    # @host_list= sort keys %{$obj->{hosts}};
  }

  my $p;
  foreach $p (@package_list)
  {
    my $px= $packs->{$p};
    my $pf= $px->{filesets};
    my @hx= sort keys %{$px->{hosts}};

    next if ($#hx == -1 && !$obj->{show_uninstalled});
    next if ($px->{available} == 0 && !$obj->{show_unavailable});

    print F <<EOHTML;
<h3>$p</h3>
<table border=1>
<tr><th>fileset<th>highest
EOHTML

    my $h;
    foreach $h (@host_list) { print F "<th>$h"; }
    print F "<th>description</tr>\n";

    my $f;
    foreach $f (sort keys %$pf)
    {
      my $fs= $pf->{$f};

      my $hl= &get_highest_level ($fs->{levels});
      print F "<tr><td>$f<td>", $hl || '&nbsp;';

      foreach $h (@host_list)
      {
        print F "<td>";
        my $hf;
        if (defined ($hf= $fs->{hosts}->{$h}))
        {
          my $xl= $hf->{level};
          print F "<font \"color=green\">" if ($xl eq $hl || !$hl);
          print F $hf->{fix_state}, ' ', $xl;
          print F "</font>" if ($xl eq $hl);

          if ($hl && $xl ne $hl)
          { # determine required fixes

            my $highest_level= &get_highest_level ({$xl => 1, $hl => 1});
# printf ("NOTE: %-10s %-30s %-10s %-10s %-10s\n", $h, $f, $xl, $hl, $highest_level);

            if ($xl ne $highest_level)
            {
              $hf->{required}= &get_fixes ($xl, $fs->{levels});
            }
            else
            {
              # print "NOTE: current level: '$xl' is higher than latest fix: $highest_level; hl: $hl\n";
            }
          }

          $hf->{printed}++;     # used for package group matrix
        }
        else { print F "&nbsp;"; }
      }
      print F '<td>', $fs->{description}, "</tr>\n";

      # [", join (':', sort keys %{$fs->{levels}}), "]\n";
    }

    print F <<EOHTML;
</table>
<hr>
EOHTML
  }
}

# --------------------------------------------------------------------------------
sub get_unreferenced_group
{
  my $obj= shift;

  my (%HOSTS, %PACKS);  # unreferenced hosts and packages
  my (@HOSTS, @PACKS);

  my ($p, $f, $h);
  my $packs= $obj->{packages};

  foreach $p (sort keys %$packs)
  {
    my $px= $packs->{$p};
    my $pf= $px->{filesets};
    my @hx= sort keys %{$px->{hosts}};

    foreach $f (sort keys %$pf)
    {
      my $fs= $pf->{$f};
      my $fsh= $fs->{hosts};

      foreach $h (keys %$fsh)
      {
        my $hf= $fsh->{$h};
        unless ($hf->{printed})
        {
          $HOSTS{$h}++;
          $PACKS{$p}++;
        }
      }
    }
  }

  @HOSTS= sort keys %HOSTS;
  @PACKS= sort keys %PACKS;
  return
  { 
    'host_list'    => \@HOSTS,
    'package_list' => \@PACKS,
  };
}

# --------------------------------------------------------------------------------
sub list_necessary_fixes
{
  my $obj= shift;
  my $host= shift;
  local *F= shift;
  my $format= shift || 'fixdist';

  my ($hf, $f, $p, $h, $rq, $rql);
  my $base= $obj->{base};

  my $packs= $obj->{packages};
  foreach $p (sort keys %$packs)
  {
    my $px= $packs->{$p};
    my $pf= $px->{filesets};
    my @hx= sort keys %{$px->{hosts}};

    foreach $f (sort keys %$pf)
    {
      my $fs= $pf->{$f};

      if (defined ($hf= $fs->{hosts}->{$host})
          && defined ($rql= $hf->{required})
         )
      {
        my $archive= $fs->{archive};

        if ($format eq 'fixdist')
        {
          foreach $rq (@$rql)
          {
            print F "$base/$archive/$f.$rq.bff\n";
          }
        }
        elsif ($format eq 'cdrom')
        {
          print F "$base/$f\n";
        }
      }
    }
  }
}

# --------------------------------------------------------------------------------
sub list_missing_filesets
{
  my $obj= shift;
  my $reference= shift;
  my $host;

  foreach $host (@_) { $obj->_list_missing_filesets ($reference, $host); }
}

# --------------------------------------------------------------------------------
sub _list_missing_filesets
{
  my $obj= shift;
  my $reference= shift;
  my $host= shift;

  my @res;
  my @res2;

  my ($f, $p, $h, $rq, $rql);
  my $packs= $obj->{packages};
  foreach $p (sort keys %$packs)
  {
## print __LINE__, " _list_missing_filesets: p='$p'\n";
    my $px= $packs->{$p};
    my $pf= $px->{filesets};
    my @hx= sort keys %{$px->{hosts}};

    foreach $f (sort keys %$pf)
    {
## print __LINE__, " _list_missing_filesets: p='$p' f='$f'\n";
      my $fs= $pf->{$f};

      my $hf1;
      if (defined ($hf1= $fs->{hosts}->{$reference}))
      {
        my $lev1= $hf1->{level};

	my $hf2;
	if (!defined ($hf2= $fs->{hosts}->{$host}))
        { # missing fileset: reference host has a fileset which is missing completely on the other host

          print "# >>> ref: $f $lev1\n";

          push (@res, [$f, $lev1]);
        }
	else
	{
          my $lev2= $hf2->{level};

	  if ($lev1 ne $lev2)
	  { # something's different...
            my $levh= get_highest_level ( { $lev1 => 1, $lev2 => 2 } );
print __LINE__, " _list_missing_filesets: p='$p' f='$f' lev1='$lev1' $lev2='$lev2' levh='$levh'\n";

	    if ($levh eq $lev1)
	    { # do something here ...
              push (@res, [$f, $lev1]); ### TODO does this work?
	      push (@res2, [$p, $f, $lev1]);
	    }
          }
	}
      }

    }
  }

  (\@res, \@res2);
}

# --------------------------------------------------------------------------------
# #Package Name:Fileset:Level:State:PTF Id:Fix State:Type:Description:
# Java.adt:Java.adt.docs:1.1.4.0: : :C: :Java Documentation 
# Java.adt:Java.adt.includes:1.1.2.0: : :C: :Java Application Development Toolkit Inc..
# Java.adt:Java.adt.src:1.1.4.0: : :C: :Java Class Source Code 
sub read_lslpp
{
  my $obj= shift;
  my $fnm= shift;
  my $id= shift || $fnm;

  my $packs= $obj->{packages};

  local *FI;

  my $time;
  if ($fnm eq '-')
  {
    *FI= *STDIN;
    $time= time;
  }
  else
  {
    open (FI, $fnm) or return undef;
    $time= (stat (FI))[9];
  }

  $obj->{hosts}->{$id}= $time;
  push (@{$obj->{host_list}}, $id);
  print __LINE__, " reading lpp listing '$fnm' id='$id'\n";

  my $lines= 0;
  while (<FI>)
  {
    chop;

    next if (/^#/);
    my ($package, $fileset, $level, $state, $ptf, $fix_state, $type, $description)=
       split (':', $_, 8); # I think, descriptions may have : in them ...

    my ($pf, $fs)= &get_fileset ($packs, $package, $fileset, $description);
    my $fsh= $fs->{hosts};
    $pf->{hosts}->{$id}++;

    $fsh->{$id}=
    {
      # installed fileset information for each host
      'level'   => $level,
      'fixstate' => $fix_state,

      # possible further relevant information at this level
      'state'   => $state,
      'ptf'     => $ptf,
      'type'    => $type,
    };
    $lines++;
  }
  
  close (FI) unless ($fnm eq '-');

  $lines;
}

# --------------------------------------------------------------------------------
# Java.adt:Java.adt.docs:1.1.4.0::I:C:::::N:Java Documentation ::::
# Java.adt:Java.adt.includes:1.1.4.0::I:C:::::N:Java Application Development Toolkit Includes ::::
# Java.adt:Java.adt.src:1.1.4.0::I:C:::::N:Java Class Source Code ::::
sub read_installp
{
  my $obj= shift;
  my $fnm= shift;
  my $archive= shift || $fnm;
  my $fmt= 'cat';

  my $packs= $obj->{packages};

  local *FI;

  if ($fnm eq '-')
  {
    *FI= *STDIN;
  }
  else
  {
    open (FI, $fnm) || die $fnm;
  }

  print "reading install media listing '$fnm'\n";

  while (<FI>)
  {
    chop;

    my @F= split (':', $_, 16);
    my $fnm= ($fmt eq 'cat') ? shift @F : undef;

    my ($package, $fileset, $level, $x1, $x2, $fix_state,
        $x3, $x4, $x5, $x6, $need_key, $description,
        $x7, $x8, $x9, $x10)= @F;

    next if ($package eq 'INVALID');

    my ($pf, $fs)= &get_fileset ($packs, $package, $fileset, $description,
                                 need_key => $need_key,
                                 fix_state => $fix_state,
                                 archive => $archive,
                                );
## print __LINE__, " pf='$pf' fs='$fs' packs='$package'\n";

    $pf->{available}++;

    $fs->{levels}->{$level}= 1;
    # T2D: $nl= &normalize_level ($level);
    # ... ->{$nl}= $level;

    $fs->{filename}= $fnm if (defined ($fnm));
  }
  
  close (FI) unless ($fnm eq '-');
}

# --------------------------------------------------------------------------------
# return references to the package and fileset structures
# T2D: packages and filesets should be objects!
sub get_fileset
{
  my ($packs, $package, $fileset, $description, %rest)= @_;
  my ($p, $pf, $f, $k);

  # print "get_fileset: '$package' '$fileset' '$description'\n" if ($DEBUG);

    unless (defined ($p= $packs->{$package}))
    {
      $p= $packs->{$package}=
      {
        'package' => $package,
        'filesets' => {},
        'hosts' => {},          # list of hosts where this package was
                                # installed at least in part
        'available' => 0,       # number of available filesets in package
      };
    }
    $pf= $p->{filesets};

    unless (defined ($f= $pf->{$fileset}))
    {
      $f= $pf->{$fileset}=
      {
        'fileset' => $fileset,
        'description' => $description,
        'levels' => {},     # available level
        'hosts' => {},      # actually installed levels at each host
      }
    }

  foreach $k (keys %rest)
  {
    $f->{$k}= $rest{$k};
  }

  ($p, $f);
}

# --------------------------------------------------------------------------------
sub get_highest_level
{
  my $levels= shift;
  my @MAX= @_;                # ... but not higher than this

  my (@H, @C, $H, $C);
  my ($i, $j, $k);

  my %LEVEL_MAP= ();
  LEVEL: foreach $k (keys %$levels)
  {
    @C= split (/[\.\-]/, $k);
    my $kk= join ('.', @C);
### print __FILE__, ' ', __LINE__, " k='$k' kk='$kk'\n";
    $LEVEL_MAP{$kk}= $k;
    # RPM version descriptions may used mixed delmiters

    for ($i= 0; $i <= $#C; $i++)
    {
      if (   ($MAX[$i] eq '' || $C[$i] <= $MAX[$i])
          && ($H[$i]   eq '' || $C[$i] >  $H[$i])
         )
      {
        for ($j= $i; $j <= $#C; $j++) { $H[$j]= $C[$j]; }
        next LEVEL;
      }
      if ($C[$i] < $H[$i]) { next LEVEL; }
    }
  }

## print join (':', %LEVEL_MAP), "\n";
  # return join ('.', @H);
  return $LEVEL_MAP{join ('.', @H)};
}

# --------------------------------------------------------------------------------
sub get_fixes
{
  my $current_level= shift;
  my @CL= split (/\./, $current_level);

  my $available_levels= shift || return ();
  my $highest_level= &get_highest_level ($available_levels, $CL[0], $CL[1]);
  return () if ($highest_level eq '' || $current_level eq $highest_level);

  my @fixes= ();

  my @HL= split (/\./, $highest_level);
  my @RL= ($HL[0], $HL[1], $HL[2], 0);
  push (@fixes, join ('.', @RL)) if ($HL[2] != $CL[2]);
  $RL[3]= $HL[3];
  push (@fixes, join ('.', @RL));

  # print "$current_level -> $highest_level: ", join (' ', @fixes), "\n";

  \@fixes;
}

# --------------------------------------------------------------------------------
sub t1
{
  &t2 ({'1.2.3.4' => 1, '1.99.3.1' => 1, '1.2.4.3' => 1});
}

sub t2
{
  my $l= shift;
  my $hl= &get_highest_level ($l);
  print "$hl <- ", join (' / ', keys %$l), "\n";
}

1;

__END__
