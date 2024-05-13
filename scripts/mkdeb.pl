#!/usr/bin/perl

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;

my $pkg_base= $ENV{PKGBASE} || '~/tmp/pkg';

my @packages= ();
my $pkg_arch= 'all';

my $compress_suffix= 'zst';
my @compress_suffixes= qw(gz xz zst);

my @pkg_paths= ();
while (my $arg= shift (@ARGV))
{
  if ($arg =~ /^--(.+)/)
  {
    my ($opt, $val)= split('=', $1);
       if ($opt eq 'arch') { $pkg_arch= $val || shift(@ARGV); }
    elsif ($opt eq 'compress-suffix') { $compress_suffix= $val || shift(@ARGV); }
    elsif ($opt =~ m#^(gz|xz|zst)$#) { $compress_suffix= $opt; }
    else { usage(); }
  }
  elsif ($arg =~ /^-/)
  {
    usage();
  }
  else
  {
    push(@pkg_paths, $arg);
  }
}

# downgrade compression to xz or gz if zstd or xz binaries are not available
$compress_suffix= 'xz' if ($compress_suffix eq 'zst' && !-x '/usr/bin/zstd');
$compress_suffix= 'gz' if ($compress_suffix eq 'xz'  && !-x '/usr/bin/xz');

if ($compress_suffix eq 'gz' && !-x '/bin/gzip')
{
  die "no usable compression algorithm";
}

foreach my $arg (@pkg_paths)
{
  mk_package_by_path($arg, $pkg_arch);
}
exit(0);

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
  foreach my $part (qw(control data))
  {
    foreach my $suffix (@compress_suffixes)
    {
      my $fnm= join('.', $part, 'tar', $suffix);
      unlink ($fnm) if (-f $fnm);
    }
  }

  cmd("(cd data && find [a-z]* -type f -print | xargs md5sum) >control/md5sums");
  cmd('(cd control && tar -cf ../control.tar .)');
  cmd('(cd data && tar -cf ../data.tar .)');

  my $control_compressed;
  my $data_compressed;
  if ($compress_suffix eq 'zst')
  {
    cmd(qw(zstd -z control.tar data.tar));
    $control_compressed= 'control.tar.zst';
    $data_compressed= 'data.tar.zst';
  }
  elsif ($compress_suffix eq 'xz')
  {
    cmd(qw(xz -z control.tar data.tar));
    $control_compressed= 'control.tar.xz';
    $data_compressed= 'data.tar.xz';
  }
  elsif ($compress_suffix eq 'gz')
  {
    cmd(qw(gzip control.tar data.tar));
    $control_compressed= 'control.tar.gz';
    $data_compressed= 'data.tar.gz';
  }

  # the ar file must contain these fils in this order and should be wiped before
  unlink($deb);
  unless (-f 'debian-binary')
  {
    open (FO, '>:utf8', 'debian-binary');
    print FO "2.0\n";
    close (FO);
  }
  cmd('ar', 'rcSv', $deb, 'debian-binary');
  cmd('ar', 'rcSv', $deb, $control_compressed);
  cmd('ar', 'rcSv', $deb, $data_compressed);

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

