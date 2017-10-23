# $Id: Catalog.pm,v 1.2 2011/09/16 18:14:25 gonter Exp $

package AIX::Software::Catalog;

=pod

=head1 NAME

AIX::Software::Catalog

=head1 SYNOPSIS

 my $cat= new AIX::Software::Catalog ();
 $cat->load_catalog ('lpp_aix6100-06-06-1115.cat');

=cut

use strict;

use AIX::Software::bff_contents;

my $installp= '/usr/sbin/installp';
my $verbose= 0;
my $drop_missing_files= 0;

sub new
{
  my $cl= shift;

  my $cat=
  {
    'files' => {},
  };
  bless $cat, $cl;
  $cat;
}

# ----------------------------------------------------------------------------
sub process_dir
{
  my $cat= shift;
  my $dir= shift;
  my $e;

  my $files= $cat->{'files'};

  my @DIRS= ();
  local *DIR;
  unless (opendir (DIR, $dir))
  {
    print "cant open directory $dir\n";
    return 0;
  }

  while (defined ($e= readdir (DIR)))
  {
    next if ($e eq '.' || $e eq '..' || $e eq '.toc');
    next if ($e =~ /FETCHLIST/ || $e =~ /FILELIST/ || $e =~ /^index.html/i || $e =~ /^ls-alsR?$/);
    next if ($e eq 'NOTES');

    my $fp= $dir . '/' . $e;
    next if (-l $fp); # TODO: maybe we should optionally allow to follow symlinks
    if (-d $fp)
    {
      push (@DIRS, $fp);
      next;
    }

    ## print __LINE__, " fp=$fp\n";
    $cat->process_bff ($fp);
  }
  closedir (DIR);

  @DIRS;
}


# ----------------------------------------------------------------------------
sub process_bff
{
  my $cat= shift;
  my $bff= shift;

  my $files= $cat->{'files'};
  if (exists ($files->{$bff}))
  {
    my $bff_p= $files->{$bff};
    $bff_p->{'found'}= 1;
    return 1;
  }

  return 0 if ($bff =~ /\.(info|html?)$/ || $bff =~ /\/\.in\./); # || !$force);

  print $bff, "\n" if ($verbose);
  my $cmd= "$installp -L -d '$bff'";
print ">>> $cmd\n";
  my $contents= `$cmd`;
  chop ($contents);

  my $bff_p= $files->{$bff}= new AIX::Software::bff_contents;
  my @fs= ();
  $bff_p->{'filesets'}= \@fs;
  $bff_p->{'found'}= 1;
  unless ($contents)
  {
    push (@fs, ['INVALID']);
    return 0;
  }

  my @contents= split (/\n/, $contents);

  foreach $contents (@contents)
  {
## print __LINE__, " $contents\n";
    my @a= split (':', $contents);
    push (@fs, \@a);
  }

  return 1;
}

# ----------------------------------------------------------------------------
sub save_catalog
{
  my $cat= shift;
  my $fnm= shift;

  my $files= $cat->{'files'};
  local *FO;

  print "saving catalog $fnm\n" if ($verbose);
  unlink ($fnm);
  open (FO, ">$fnm") || die "cant write catalog '$fnm'";
  foreach $fnm (sort keys %$files)
  {
    my $bff_p= $files->{$fnm};

    if ($drop_missing_files and !$bff_p->{'found'})
    {
      print "dropping $fnm\n";
      next;
    }

    foreach my $p (@{$bff_p->{'filesets'}})
    {
      if (ref ($p) ne 'ARRAY')
      {
	print "ATTN: cat info '$p' for '$fnm' is not valid\n";
	next;
      }
      print FO join (':', $fnm, @$p), "\n";
    }
  }
  close (FO);
}

# ----------------------------------------------------------------------------
sub load_catalog
{
  my $cat= shift;
  my $fnm= shift;

  my $files= $cat->{'files'};
  print "loading catalog $fnm\n" if ($verbose);
  local *FI;
  open (FI, $fnm) or return undef;
  $cat->{'fnm'}= $fnm;
  while (<FI>)
  {
    chop;
    my ($fnm, @rest)= split (':', $_);
    next unless (-r $fnm);
    if ($fnm =~ m#/\.in\.#)
    {
      print "dropping $fnm\n";
      next;
    }

    my $bff_p= $files->{$fnm};
    unless (defined ($bff_p))
    {
      $bff_p= $files->{$fnm}= new AIX::Software::bff_contents;
    }

    push (@{$bff_p->{'filesets'}}, \@rest);
  }
  close (FI);

  1;
}

sub mk_fileset_cross_ref
{
  my $cat= shift;

  my $files= $cat->{'files'};
  my %packages= ();
  my %filesets= ();
  foreach my $fnm (sort keys %$files)
  {
    my $bff_p= $files->{$fnm};
    my %cnt_p= ();
    foreach my $p (@{$bff_p->{'filesets'}})
    {
      my ($package, $fileset, $vrmf)= @$p;
      $cnt_p{$package}++;

      $packages{$package}->{'filesets'}->{$fileset}= [$fnm, $vrmf];
      $packages{$package}->{'files'}->{$fnm}= [$fileset, $vrmf];

      $filesets{$fileset}->{'files'}->{$fnm}= [$package, $vrmf];
    }

    my $cnt_p= scalar %cnt_p;
    if ($cnt_p > 1)
    {
      ## print "ATTN: $fnm contains $cnt_p packages!\n";
      push (@{$bff_p->{'skip'}}, "multiple packages in bff");
    }
  }

  $cat->{'packages'}= \%packages;
  $cat->{'filesets'}= \%filesets;

  1;
}

sub rename_bff_files
{
  my $cat= shift;
  my $doit= shift;

  my $files= $cat->{'files'};
  my $packages= $cat->{'packages'};
  foreach my $fnm (sort keys %$files)
  {
    my $bff_p= $files->{$fnm};
    next if (exists ($bff_p->{'skip'}));
    my @fs= @{$bff_p->{'filesets'}};

    my @path= split ('/', $fnm);
    my $r_fnm= pop (@path);
    my $w_fnm;
    next if ($fs[0]->[0] eq 'INVALID');
    my ($package, $fileset, $vrmf)= @{$fs[0]};

    if (@fs == 1)
    { # the prefered filename contains fileset name and vrmf
      $w_fnm= join ('.', $fileset, $vrmf, 'bff');
    }
    elsif (@fs > 1)
    { # if a file contains multiple filesets, we can name the file after the package
      # NOTE: take vrmf from first fileset in list; I do not know if there are
      # filesets with differen vrmf's around, but this is possible.
      ## print "ATTN: multiple filesets in bff: $fnm\n";
      $w_fnm= join ('.', $package, $vrmf, 'bff');

    }

    if (defined ($w_fnm) && $r_fnm ne $w_fnm)
    {
      my $W_fnm= join ('/', @path, $w_fnm);

      if (-f $W_fnm)
      {
	print "ATTN: cant rename $fnm to $W_fnm, new filename already exists!\n";
      }
      else
      {
        my $cmd= "mv -i '$fnm' '$W_fnm'";
	print $cmd, "\n";
	if ($doit)
	{
	  system ($cmd);

          delete ($files->{$fnm});
          $files->{$W_fnm}= $bff_p;
	}
      }
    }
  }
}

1;

__END__

