#!/usr/bin/perl
# $Id: sc2.pl,v 1.1 2007/08/31 15:49:19 gonter Exp $

=pod

=head1 NAME

sc2.pl

=head1 DESCRIPTION

stage copy two -- copy files from install area to stage and call mkinstallp

=cut

use strict;

# use AIX::Software::Package;
# use AIX::Software::Fileset;
use AIX::Software::Template;
use Util::print_refs;

my $target_dir= 'usr/local';

my $doit= 0;
my $verbose= 1;
my $stage= 'stage';

my @JOBS= ();
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-doit') { $doit= 1; }
    elsif ($arg eq '-q')    { $verbose= 0; }
    else { &usage; }
    next;
  }
  
  push (@JOBS, $arg);
}

foreach $arg (@JOBS)
{
  &process ($arg);
}

exit (0);

sub process
{
  my $fnm= shift;

  my $cat= new AIX::Software::Template ();

  $cat->parse_catalog ($fnm);

  my ($pkg, $filesets)= $cat->get ('pkg', 'filesets');
  my ($pkg_name, $pkg_vrmf)= $pkg->get ('Package Name', 'Package_VRMF');

  unless ($pkg_name)
  {
    die "no Package Name found";
  }

  my $TODO= <<EOX;
EOX

  # guess a template filename and stage directories
  my $stage_dir= join ('/', $stage, $pkg_name);
  my $template_file= $stage_dir . '.template';
  unless (-d $stage)
  {
    my $rc= system ("mkdir -p '$stage_dir'");
    print "rc=$rc\n";
    die "mkdir rc=$rc" if ($rc != 0);
  }

  $pkg->set ('template' => $template_file, 'stage' => $stage_dir);

  foreach my $fs (@$filesets)
  {
    $fs->set ('target_dir' => $target_dir, 'dst' => $stage_dir, 'src' => "/$target_dir");
    $fs->copy_to_stage ();
  }

  ## print_refs (*STDOUT, 'cat', $cat);

  $cat->print_template ();
  $pkg->mkinstallp ();
}

