#!/usr/local/bin/perl
#
# atm interface statistics
#
# written:       2000-03-08
# latest update: 2000-03-08 15:27:55
#

use strict;
BEGIN { my $x= $0; my @x= split (/\//, $x); pop (@x);
  $x= join ('/', @x);
  unshift (@INC, $x);
  # use lib $x;
}
# use lib '.';

my $ID= '$Id: atmstats.pl,v 1.1 2000/03/08 21:08:09 gonter Exp $';

use AIX::dev::atm;

my $adapter= 'atm0';
my $nw_device= 'at0';
my $sleep_time= 60;
my $loop_count= 1; # -1 loop forever
my $log= 1;

my $arg;
my $mode= 'dir';
my @DIRS;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-dir') { $mode= 'dir'; }
    else { &usage; exit (0); }
    next;
  }

  if ($mode eq 'dir')
  {
    push (@DIRS, $arg);
  }
}

foreach $arg (@DIRS)
{
  &process_dir ($arg);
}
exit (0);

# ----------------------------------------------------------------------------
sub process_dir
{
  my $dir= shift || '.';
  my $e;

  opendir (DIR, $dir) || die;
  while (1)
  {
    $e= readdir (DIR);
    last unless (defined ($e));
    next if ($e eq '.' || $e eq '..');
    &process_file ("$dir/$e");
  }
  closedir (DIR);
}

# ----------------------------------------------------------------------------
sub process_file
{
  my $fnm= shift;

  my $obj= new AIX::dev::atm::stats ($fnm, 'is_file' => 1);
  my $sd= $obj->{'driver'};
  # print join (':', %$sd), "\n";

  my @watch= qw(lrg_bufs);
  # my @watch= qw(max_sml_bufs max_med_bufs max_lrg_bufs max_hug_bufs max_spec_bufs);

  foreach $a (@watch)
  {
    my $used=      $sd->{"used_$a"};
    my $allocated= $sd->{"max_$a"};
    my $errors=    $sd->{"err_$a"};
    printf ("%s %5d %5d %7d\n", $fnm, $used, $allocated, $errors);
  }
}

exit (0);

# ----------------------------------------------------------------------------
sub usage
{
  print <<EOX;
usage: atmstats.pl [-opts]

Options:
$ID
EOX
}

