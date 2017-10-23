#!/usr/bin/perl
# $Id: Fileset.pm,v 1.3 2008/10/08 13:22:46 gonter Exp $

# NOTE:
# packages "AIX::Software::Package" and "AIX::Software::Fileset"
# are used to generate templates for mkinstallp

package AIX::Software::Fileset;

use strict;

my $verbose= 0;
my $doit= 1;

my %DEFAULTS=
(
  'Fileset Name' => 'dummy.package.fileset',
  'Fileset VRMF' => '1.0.0.0',
  'Fileset Description' => 'dummy fileset description',
  'Bosboot required' => 'N',
  'License agreement acceptance required' => 'N',
  'Include license files in this package' => 'N',
  'Requisites' => '',
);

my @Fileset_Fields=
(
  'Fileset Name',
  'Fileset VRMF',
  'Fileset Description',
  'Bosboot required',
  'License agreement acceptance required',
  'Include license files in this package',
  'Requisites',
);

sub new
{
  my $class= shift;

  my $obj=
  {
    'usr_files' => [],   # list of files
    'usr_catalog' => {}, # files and their md5 sums and size, if known
  };
  bless $obj, $class;

  $obj->defaults ();
  $obj->set (@_);

  $obj;
}

sub defaults
{
  my $obj= shift;

  foreach my $kw (keys %DEFAULTS)
  {
    $obj->{$kw}= $DEFAULTS{$kw} unless (exists ($obj->{$kw}));
  }
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

    if ($par eq 'verbose') { $verbose= $par{'verbose'}; }
    elsif ($par eq 'doit') { $doit= $par{'doit'}; }
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

sub copy_to_stage
{
  my $desc= shift;

  my @USRFiles= ();

  my ($usr_files, $td, $d_src, $d_dst)= map { $desc->{$_} } qw(usr_files target_dir src dst);
  my @f= @$usr_files;

  foreach my $f (@f)
  {
    my $f_src= join ('/', $d_src, $f);
    my $f_dst= join ('/', $d_dst, $td, $f);
    my $f_template= join ('/', '', $td, $f);
    ## print "f_src='$f_src' f_dst='$f_dst'\n";

    unless (-f $f_src)
    {
      print "ERR: source not found: $f_src\n";
      next;
    }
    &check_path ($f_dst);

    &cp ($f_src, $f_dst);
    push (@USRFiles, $f_template);
  }

  $desc->{'USRFiles'}= \@USRFiles;
}

sub check_path
{
  my $f= shift;

  my @f= split ('/', $f);
  pop (@f);
  my $p= join ('/', @f);

  unless (-d $p)
  {
    &do ("mkdir -p '$p'");
  }
}

sub cp
{
  my ($f_src, $f_dst)= @_;
  &do ("cp '$f_src' '$f_dst'");
}

sub do
{
  foreach my $c (@_)
  {
    print ">>> $c\n" if ($verbose);
    system ($c) if ($doit);
  }
}

sub print_template
{
  my $fs= shift;
  local *FO= shift;

  print FO "Fileset\n";
  foreach my $kw (@Fileset_Fields)
  {
    my ($v)= $fs->get ($kw);
    print FO "  $kw: $v\n";
  }

  my ($USRFiles)= $fs->get ('USRFiles');
  print FO "  USRFiles\n";
  foreach my $fnm (sort @$USRFiles)
  {
    print FO "    ", $fnm, "\n";
  }

  print FO <<EOX;
  EOUSRFiles
  ROOT Part: N
  ROOTFiles
  EOROOTFiles
EOFileset
EOX

  1;
}

1;

