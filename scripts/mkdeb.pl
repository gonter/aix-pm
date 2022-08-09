#!/usr/bin/perl

use strict;

my $pkg_base= $ENV{PKGBASE} || '~/tmp/pkg';

while (my $arg= shift (@ARGV))
{
  mk_package_by_path($arg);
}

sub mk_package_by_path
{
  my $arg= shift;

  my @parts= split('/', $arg);
  my $pkg_version= pop(@parts);
  my $pkg_epoch= pop(@parts);
  my $pkg_name= pop(@parts);
  my $base= join('/', @parts);

  mk_package($base, $pkg_name, $pkg_epoch, $pkg_version);
}

sub cmd
{
  my @c= @_;

  print "cmd: [", join(' ', @c), "]\n";
  system (@c);
}

sub mk_package
{
  my $base= shift;
  my $pkg_name= shift;
  my $pkg_epoch= shift;
  my $pkg_version= shift;

  my $deb= '../../../'. $pkg_name . '-';
  $deb .= $pkg_epoch.':' if ($pkg_epoch > 0);
  $deb .= $pkg_version .'.deb';
  print __LINE__, " deb=[$deb]\n";

  chdir($base)        or die "base not found [$base]";
  chdir($pkg_name)    or die "pkg_name not found [$pkg_name]";
  chdir($pkg_epoch)   or die "pkg_epoch not found [$pkg_epoch]";
  chdir($pkg_version) or die "pkg_version not found [$pkg_version]";

  # mk_md5sums();
  unlink('control.tar.xz');
  unlink('data.tar.xz');

  cmd("(cd data && find [a-z]* -type f -print | xargs md5sum) >control/md5sums");
  cmd('(cd control && tar -cf ../control.tar .)');
  cmd('(cd data && tar -cf ../data.tar .)');

  cmd(qw(xz -zv control.tar data.tar));

  # the ar file must contain these fils in this order
  cmd('ar', 'rcSv', $deb, 'debian-binary');
  cmd('ar', 'rcSv', $deb, 'control.tar.xz');
  cmd('ar', 'rcSv', $deb, 'data.tar.xz');

  chdir('..');
  chdir('..');
  chdir('..');
}

sub mk_md5sums
{
  # my $dir= shift;

  # my $ddir= join('/', $dir, 'data');
  # chdir('data') or die;

  cmd("(cd data && find [a-z]* -type f -print | xargs md5sum) >control/md5sums");
  # chdir('..');
}

