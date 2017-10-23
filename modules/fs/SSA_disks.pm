#!/usr/local/bin/perl
# $Id: SSA_disks.pm,v 1.1 2006/05/05 10:26:38 gonter Exp $

use strict;
use AIX::fs::vg;
use MIME::Media_Types;

package AIX::fs::SSA_disks;

my %LV_TYPE_not_listed= map { $_ => 1 } qw(boot paging jfslog);

sub new
{
  my $class= shift;
  my $obj=
  {
    'pdisk2hdisk' => {},
    'hdisk2pdisk' => {},
    'hdisk2vg' => {},

    'pdisks' => {},  # information about pdisks
    'vgs' => {},     # information about VGs
  };
  bless $obj;
}

sub print_vg_html
{
  my $obj= shift;

  my $vgs= $obj->{'vgs'};
  my $pdisks= $obj->{'pdisks'};

  my %pdisk_printed= (); # names of pdisks printed

  print <<EOX;
<table border=1>
<tr>
  <th>VG</th>
  <th>hdisk</th>
  <th>pdisk</th>
  <th>location</th>
  <th>remarks</th>
</tr>
EOX

  my $vg_name;
  foreach $vg_name (sort keys %$vgs)
  {
    my $vg= $vgs->{$vg_name};
    my $d= $obj->get_vg_disk_data ($vg);
    my $t_num_pdisks= $d->{num_pdisks};

    ## &MIME::Media_Types::print_refs (*STDOUT, $vg_name, $d);

    my $vg_printed= 0;
    my $vg_printed_comment= 0;

    my $hd_info= $d->{hd};
    my ($hdi, $pd_name);
    foreach $hdi (@$hd_info)
    {
      my $hd_name= $hdi->{'name'};
      my $pd_info= $hdi->{'pdisks'};

      my $hd_printed= 0;
      my $num_pdisks= @$pd_info;
      unless ($num_pdisks)
      {
	$pd_info= [ 'non-ssa' ];
        $num_pdisks= 1;
      }

# print __LINE__, "  num_pdisks=$num_pdisks pd_info=$pd_info\n";
      foreach $pd_name (@$pd_info)
      {
        print "<tr>\n";
	unless ($vg_printed)
	{
          print "  <td rowspan=$t_num_pdisks><a href=\"#vg:$vg_name\">$vg_name</a></td>\n";
	  $vg_printed= 1;
        }

	unless ($hd_printed)
	{
          print "  <td rowspan=$num_pdisks>$hd_name</td>\n";
	  $hd_printed= 1;
	}

        if ($pd_name eq 'non-ssa')
	{
          print "  <td colspan=2>&nbsp;</td>\n";
	}
	else
	{
	  my $loc= $pdisks->{$pd_name}->{'location'};
          print "  <td>$pd_name</td>\n";
          print "  <td>$loc</td>\n";
	  $pdisk_printed{$pd_name}++;
	}

	unless ($vg_printed_comment)
	{
	  my $vg_comment= $vg->{'vg_remark'} || '&nbsp;';
          print "  <td rowspan=$t_num_pdisks>$vg_comment</td>\n";
	  $vg_printed_comment= 1;
        }

        print "</tr>\n";
      }
    }
  }

  my $pd;
  foreach $pd (sort keys %$pdisks)
  {
    my $pdi= $pdisks->{$pd};
    my $pd_name= $pdi->{'name'};
    next if ($pdisk_printed{$pd_name});

    my $pd_loc=  $pdi->{'location'};

    print "<tr><td colspan=2>&nbsp;</td>\n";
          print "  <td>$pd_name</td>\n";
          print "  <td>$pd_loc</td>\n";
        print "</tr>\n";
  }

  print <<EOX;
</table>
<h1>Volume Groups</h1>
EOX

  foreach $vg_name (sort keys %$vgs)
  {
    my $vg= $vgs->{$vg_name};
    my $lsvg= $vg->{'lsvg HTML'};
    next unless ($lsvg);

    print <<EOX;
<hr>
<h2><a name="vg:$vg_name">$vg_name</a></h2>
EOX
    print "<pre>\n", $lsvg, "</pre>\n";
  }
}

sub get_vg_disk_data
{
  my $obj= shift;
  my $vg= shift;

  my $num_t_pdisks= 0;

  my $h2p= $obj->{'hdisk2pdisk'};
  my @hdisks= sort @{$vg->{'hdisks'}};

  my $hd_info= [];
  my $res=
  {
    'hd' => $hd_info,
  };

  my ($hdisk, $pdisk);
  foreach $hdisk (@hdisks)
  {
    my @pdisks= &get_pdisk_list ($h2p, $hdisk);
    my $hdx= { 'name' => $hdisk, 'pdisks' => \@pdisks };
    push (@$hd_info, $hdx);
    $num_t_pdisks += @pdisks || 1 ;
  }

  $res->{num_pdisks}= $num_t_pdisks;
  $res;
}

sub get_pdisk_list
{
  my $h2p= shift;
  my $hd= shift;
  my $pdisks= $h2p->{$hd};
  ## print "hd: $h2p $hd -> $pdisks\n";
  return () unless ($pdisks);
  return @{$pdisks};
}

sub map_hdisk_vg
{
  my $obj= shift;

  my $cmd= "/usr/sbin/lspv";
  my @res= split (/\n/, `$cmd`);
  my $h2vg= $obj->{hdisk2vg};
  my $vgs= $obj->{vgs};
  my $l;
  foreach $l (@res)
  {
    ## print "[$l]\n";
    my ($hdisk, $hd_id, $vg_name)= split (' ', $l);

    # next if ($vg_name eq 'None');

    $h2vg->{$hdisk}= $vg_name;
    my $vg= $vgs->{$vg_name};
    unless (defined ($vg))
    {
      $vg= new AIX::fs::vg ($vg_name);
      $vgs->{$vg_name}= $vg;
    }
    push (@{$vg->{hdisks}}, $hdisk);
  }
}

sub add_vg_remarks
{
  my $obj= shift;
  my $vg_name= shift;

  my $vgs= $obj->{vgs};
  my $vgc= \$vgs->{$vg_name}->{'vg_remark'};
  $$vgc .= join ("\n", @_) if (defined ($vgc));
}

sub lsvg_get_lvfs
{
  my $obj= shift;
  my $vg_name= shift;

  my $vgp= $obj->{vgs}->{$vg_name};
  my $cmd= "lsvg -l '$vg_name'";
  ## print ">>> $cmd\n";
  my $res= `$cmd`;
  $vgp->{'lsvg -l'}= $res;

  my @res= split ("\n", $res);
  my @res2= ();
  my @ptrs= ();
  my $l;
  while ($l= shift (@res))
  {
    ## print ">>>> $l\n";
    if ($l =~ /^(\w+):/) {} # { $l= "<a name=\"vg:$1\">$1</a>"; } # VG name
    elsif ($l =~ /^LV NAME/) {}
    else
    {
      my ($lv_name, $type, $lps, $pps, $pvs, $lv_state, $mp)= split (' ', $l, 7);
      ## print "lv_name='$lv_name' mp='$mp'\n";
      $l=~ s|$lv_name|<a name=\"lv:$lv_name\">$lv_name</a>|;

      next if (exists ($LV_TYPE_not_listed{$type}));
      my $ptr= "<a href=\"#lv:$lv_name\">$mp</a>";
      push (@ptrs, $ptr);
    }

    push (@res2, $l);
  }

  $vgp->{'lsvg HTML'}= `lsvg '$vg_name'` . "<br>" . join ("\n", @res2) . "\n";

  ($vgp, \@ptrs);
}

sub upd_vg_fs
{
  my $obj= shift;

  my $vgs= $obj->{vgs};
  my @vg_names= keys %$vgs;
  ## print "VG Names: ", join (',', @vg_names), "\n";
  my $vg_name;
  foreach $vg_name (@vg_names)
  {
    next if ($vg_name eq 'None');

    my ($vgp, $ptrs)= $obj->lsvg_get_lvfs ($vg_name);
    if (@$ptrs)
    {
      my $vgc= \$vgp->{'vg_remark'};
      $$vgc .= "<ul>\n<li>" . join ("\n<li>", @$ptrs) . "\n</ul>\n";
    }
  }
}

sub read_vg_remarks
{
  my $obj= shift;
  my $fnm= shift;

  return undef unless open (FI, $fnm);

  # print "reading $fnm\n";
  my $vgs= $obj->{vgs};
  my $vg_name;
  my $vgc= undef;
  while (<FI>)
  {
    chop;
    next if (/^#/|| /^\s*$/);

    if (/^\[(.+)\]/)
    {
      $vg_name= $1;
      $vgc= \$vgs->{$vg_name}->{'vg_remark'};
      next;
    }
    $$vgc .= $_ if (defined ($vgc));
  }
  close (FI);
}

sub map_pdisk_hdisk
{
  my $obj= shift;
  my @pdisks= @_;

  my $p2h= $obj->{pdisk2hdisk};
  my $h2p= $obj->{hdisk2pdisk};
  my $pdisk;
  foreach $pdisk (@pdisks)
  {
    my $cmd= "/usr/sbin/ssaxlate -l '$pdisk'";
    ### print ">>> $cmd\n";
    my $r= `$cmd`;
    chop ($r);
    $r=~ s/\s*//g;  # sometimes printed with space at the end!
    ### print ">>> pdisk zu hdisk: [$pdisk] [$r]\n";
    $p2h->{$pdisk}= $r;
    push (@{$h2p->{$r}}, $pdisk);
  }
}

sub ssa_pdisk_list
{
  my $obj= shift;

  my $cmd= "/usr/sbin/lsdev -CS1 -cpdisk -sssar -F name";
  my @res= split (' ', `$cmd`);
  my %r2= map { $_ => { 'name' => $_ } } @res;
  $obj->{pdisks}= \%r2;

  $cmd= "/usr/sbin/lscfg";
  my @res2= split ("\n", `$cmd`);
  my $l;
  foreach $l (@res2)
  {
    ## print "[$l]\n";
    if ($l =~ /^\+ (pdisk\d+)\s+(\S+)\s+(.+)/)
    {
      my ($pdisk, $location, $comment)= ($1, $2, $3);
      $r2{$pdisk}->{'location'}= $location;
      $r2{$pdisk}->{'comment'}= $comment;
    }
  }

  @res;
}

1;
