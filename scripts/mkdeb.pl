#!/usr/bin/perl

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;

my $pkg_base= $ENV{PKGBASE} || '~/tmp/pkg';

my @packages= ();
my $pkg_arch= 'all';

while (my $arg= shift (@ARGV))
{
  if ($arg eq '--arch') { my $pkg_arch= shift(@ARGV); }
  else
  {
    mk_package_by_path($arg, $pkg_arch);
  }
}

sub mk_package_by_path
{
  my $arg= shift;
  my $pkg_arch= shift;

  my @parts= split('/', $arg);
  my $pkg_version= pop(@parts);
  my $pkg_epoch= pop(@parts);
  my $pkg_name= pop(@parts);
  my $base= join('/', @parts);

  mk_package($base, $pkg_name, $pkg_epoch, $pkg_version, $pkg_arch);
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
  my $pkg_arch= shift;

  chdir($base)        or die "base not found [$base]";
  chdir($pkg_name)    or die "pkg_name not found [$pkg_name]";
  chdir($pkg_epoch)   or die "pkg_epoch not found [$pkg_epoch]";
  chdir($pkg_version) or die "pkg_version not found [$pkg_version]";

  my $ctrl= Debian::Package::Control->read_control_file ('control/control');
  # print __LINE__, " ctrl: ", Dumper($ctrl);
  unless (defined ($pkg_arch))
  {
    $pkg_arch= $ctrl->{fields}->{Architecture}->{value} || 'all';
  }

  my $deb= '../../../'. $pkg_name . '_';
  # my $deb= $pkg_name . '-';
  $deb .= $pkg_epoch.':' if ($pkg_epoch > 0);
  $deb .= $pkg_version . '_' . $pkg_arch .'.deb';
  print __LINE__, " deb=[$deb]\n";

  # mk_md5sums();
  unlink('control.tar.xz');
  unlink('data.tar.xz');

  cmd("(cd data && find [a-z]* -type f -print | xargs md5sum) >control/md5sums");
  cmd('(cd control && tar -cf ../control.tar .)');
  cmd('(cd data && tar -cf ../data.tar .)');

  cmd(qw(xz -z control.tar data.tar));

  # the ar file must contain these fils in this order and should be wiped before
  unlink($deb);
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

package Debian::Package::Control;

sub read_control_file
{
  my $class= shift;
  my $fnm= shift;

  open (FI, '<:utf8', $fnm) or die "can't read control file [$fnm]";
  my @segments;
  my $segment;
  my %fields;
  while (<FI>)
  {
    chop;
    print __LINE__, " l=[$_] segment=[$segment]\n";
    if ($_ =~ m/^#/)
    {
      if (defined ($segment) && $segment->{type} eq 'comment')
      {
        push (@{$segment->{lines}} => $_);
      }
      else
      {
        $segment= { type => 'comment', lines => [ $_ ] };
        push (@segments, $segment);
      }
    }
    elsif ($_ =~ m#^ #)
    {
      die 'invalid continuation' unless (defined ($segment));
      push (@{$segment->{lines}} => $_);
    }
    elsif ($_ =~ m#^([A-Z][\w\-_]+): *(.+)#)
    {
      my ($field, $value)= ($1, $2);
      print __LINE__, " field=[$field] value=[$value]\n";
      $segment= { type => 'field', field => $field, value => $value, lines => [ $_ ] };
      push (@segments, $segment);
      $fields{$field}= $segment;
    }
  }
  close(FI);

  my $res= { fields => \%fields, segments => \@segments };
  bless ($res, $class);
}

