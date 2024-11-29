#!/usr/bin/perl

use strict;
use IPC::Run;

my @FILES;
while (defined (my $arg= shift(@ARGV)))
{
  if ($arg =~ /^-/)
  {
    die;
  }
  else
  {
    push (@FILES, $arg);
  }
}

foreach my $fnm (@FILES)
{
  test_tar($fnm);
}

exit;

sub test_tar
{
  my $fnm= shift;
  my @cmd= ('tar', '-tvf', $fnm);
  my $tar_output;
  my $tar_input;
  my $tar_stderr;

  my $rc= IPC::Run::run(\@cmd, \$tar_input, \$tar_output, \$tar_stderr);
  # my $rc= system(@cmd);
  print __LINE__, " cmd=[", join(' ', @cmd), "]\n";
  print __LINE__, " rc=[$rc]\n";
  # print __LINE__, " tar_output=[$tar_output]\n";
  print __LINE__, " tar_stderr=[$tar_stderr]\n";

  $rc;
}


