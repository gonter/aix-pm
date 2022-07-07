#!/usr/local/bin/perl
#
# FILE AIX/Software/Maintenance.pm
#
# written:       1998-05-09
# latest update: 2000-01-30  1:23:51
#
# $Id: toc.pm,v 1.2 2008/10/08 15:37:32 gonter Exp $
#

use strict;

package AIX::Software::toc::fileset;

=pod

=head1 NAME

AIX::Software::fileset

=head1 DESCRIPTION

Module for AIX software maintenance, toc fileset handling

=cut

# --------------------------------------------------------------------------------
sub new
{
  my $class= shift;
  my %more= @_;

  my $obj=
  {
  };

  my $k;
  foreach $k (keys %more)
  {
    $obj->{$k}= $more{$k};
  }

  bless $obj, $class;
}

package AIX::Software::toc::package;

=pod

=head1 NAME

AIX::Software::package

=head1 DESCRIPTION

Module for AIX software maintenance, toc package handling

=cut

# --------------------------------------------------------------------------------
sub new
{
  my $class= shift;
  my %more= @_;

  my $obj=
  {
    'filesets' => [],
  };

  my $k;
  foreach $k (keys %more)
  {
    $obj->{$k}= $more{$k};
  }

  bless $obj, $class;
}

package AIX::Software::toc;

=pod

=head1 NAME

AIX::Software::toc

=head1 DESCRIPTION

Module for AIX software maintenance, toc file handling

=cut

my $VERSION= '0.11';

# --------------------------------------------------------------------------------
sub new
{
  my $class= shift;
  my %more= @_;

  my $obj=
  {
    'packages' => [],
  };

  my $k;
  foreach $k (keys %more)
  {
    $obj->{$k}= $more{$k};
  }

  bless $obj, $class;
}

# --------------------------------------------------------------------------------
sub read_toc
{
  my $obj= shift;
  my $fnm= shift;
  my $lnr= 0;

  local *FI;

  if ($fnm eq '-') { *FI= *STDIN;}
  else
  {
    open (FI, $fnm) || die $fnm;
  }

  print "reading toc '$fnm'\n";

  $obj->{'fnm'}= $fnm;
  $obj->{'fmt'}= '_unknown_';

  ## my $hdr= <FI>; chop ($hdr); print __LINE__, " >>> lnr='$lnr' hdr='$hdr'\n";

  my $c_package_name= undef;
  my $c_package= undef;
  my $c_fileset= undef;

  my $state= 0;
  TOC: while (<FI>)
  {
    chop;
    $lnr++;
## print __LINE__, " >> lnr='$lnr' state='$state' _='$_'\n";

    if ($state == 0 && /^(\d+)\s(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\s(\d+)$/ && $lnr == 1)
    { # this is the timestamp in a .toc file
      my ($x1, $MM, $DD, $hh, $mm, $ss, $YY, $x2)= ($1, $2, $3, $4, $5, $6, $7, $8);
      my $YYYY += $YY + (($YY >= 70) ? 1900 : 2000);
      my $ts= sprintf ("%4d-%02d-%02dT%02d:%02d:%02d", $YYYY, $MM, $DD, $hh, $mm, $ss);
      ## print ">>> YY='$YY' ts='$ts'\n";
      # known values for x1: 0, x2: 2
      $obj->{'fmt'}= '.toc';
    }
    elsif ($state == 0 && /^(\d+)\s(\w+)\s(\w+)\s(\S+)\s{$/) # no } here
    { # this is a package name in lpp_name file
      my ($format, $platform, $pkg_type, $pkg_name)= ($1, $2, $3, $4);
## print __LINE__, " >>> lnr='$lnr' pkg_name='$pkg_name' format='$format' platform='$platform' pkg_type='$pkg_type'\n";

      $state= 1;
      $obj->{'fmt'}= 'lpp_name';

      $c_package_name= $pkg_name;
      $c_package= new AIX::Software::toc::package (
	'pkg_name' => $pkg_name,
	'format'   => $format,
	'platform' => $platform,
	'pkg_type' => $pkg_type,
      );
      push (@{$obj->{'packages'}}, $c_package);
    }
    elsif ($state == 0 && /^(\S+)\s(\d+)\s(\w+)\s(\w+)\s(\S+)\s{$/) # no } here
    { # in a toc file, this is the line that describes the package
      my ($bff_name, $format, $platform, $pkg_type, $pkg_name)= ($1, $2, $3, $4, $5);
## print __LINE__, " >>> lnr='$lnr' pkg_name='$pkg_name' format='$format' platform='$platform' pkg_type='$pkg_type' bff_name='$bff_name\n";
      $state= 1;

      $c_package_name= $pkg_name;
      $c_package= new AIX::Software::toc::package (
	'bff_name' => $bff_name,
	'pkg_name' => $pkg_name,
	'format'   => $format,
	'platform' => $platform,
	'pkg_type' => $pkg_type,
      );
      push (@{$obj->{'packages'}}, $c_package);
    }
    elsif ($state == 1 && /^(\S+)\s(\d+)\.(\d+)\.(\d+)\.(\d+)\s(\d+)\s([NbYBn])\s([BHU])\s(\S+)\s(.+)/)
    {
      my ($fset_name, $l_ver, $l_rel, $l_mod, $l_fix, $vol, $bosboot, $content, $lang, $desc)= ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
      $state= 2;

      # normalize version codes
      $l_ver += 0; $l_rel += 0; $l_mod += 0; $l_fix += 0;

      # bosboot: N .. do not invoke bosboot; b .. invoke bosboot; [YBn] .. not documented but found in real data
      # just a guess what these undocumented values might be
      # TODO: maybe we should fix those values only if requested
      if ($bosboot eq 'Y' || $bosboot eq 'B') { $bosboot= 'b'; }
      elsif ($bosboot eq 'n') { $bosboot= 'N'; }

      # the description may contain a comment too
      my $comments= '';
      if ($desc =~ /#(.+)/)
      {
	$comments= $1;
	$comments =~ s/^\s*//; $comments =~ s/\s*$//;
      }
      $desc =~ s/^\s*//; $desc =~ s/\s*$//;

      my $ver= join ('.', $l_ver, $l_rel, $l_mod, $l_fix);

## print __LINE__, " >>> lnr='$lnr' fset_name='$fset_name' ver='$ver' vol='$vol' bosboot='$bosboot' content='$content' lang='$lang' desc='$desc' comments='$comments'\n";

      $c_fileset= new AIX::Software::toc::fileset (
        'fset_name' => $fset_name,
	'ver'       => $ver,
	'l_ver'     => $l_ver,
	'l_rel'     => $l_rel,
	'l_mod'     => $l_mod,
	'l_fix'     => $l_fix,
	'vol'       => $vol,
	'bosboot'   => $bosboot,
	'content'   => $content,
	'lang'      => $lang,
	'desc'      => $desc,
	'comments'  => $comments,
	'pkg_name'  => $c_package_name,
	'pkg_obj'   => $c_package,
      );
      push (@{$c_package->{'filesets'}}, $c_fileset);
      $obj->{'_toc_'}->{$c_package_name}->{$fset_name}->{$ver}= $c_fileset;
    } # no { here
    elsif ($state == 1 && $_ eq '}')
    {
      $state= 0;
    }
    elsif ($state == 2 && $_ eq '[') # no ] here
    {
      $state= 3;
    }
    elsif ($state >= 3 && $state <= 10)
    {
      if ($_ eq '%') { $state++; }
      # no [ here
      elsif ($_ eq ']') { $state= 1; } # other filesets may follow now
      else
      {
	my $handle;

	   if ($state == 3) { $handle= 's_req'; }
	elsif ($state == 4) { $handle= 's_size'; }
	elsif ($state == 5) { $handle= 's_supersede'; }
	elsif ($state == 6) { $handle= 's_fix'; } # Bam! Oida!
	else { $handle= 's_'.$state; }

 	push (@{$c_fileset->{$handle}}, $_);
      }
    }
    else
    {
print __LINE__, " >>>>>> ATTN unknown line: lnr='$lnr' state='$state' _='$_'\n";
    }
  }
  close (FI);
}

1;

__END__
