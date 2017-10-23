#!/usr/bin/perl
# $Id: fillup.pl,v 1.5 2015/10/20 09:26:45 gonter Exp $

=head1 NAME

  fillup.pl

=head1 DESCRIPTION

Simple script to fill up target directory with copies of some input
file.  This can be used to overwrite a disk with (random) data.

=head1 USAGE

  -i <input-file>
  -o <target-directory>
  -c <count> ... only copy that many times
  --mb <count> ... generate random file; number of MiB; (1048576 * $count bytes)
  --dryrun ... only show what would be done
  --doit   ... perform the copy

=head1 NOTES

A suitable input file may be generated with a command like that:

  dd if=/dev/urandom of=urxn bs=1048576 count=1

=head1 BUGS

presumably.

=head1 AUTHOR

  g.gonter@ieee.org

=cut

use strict;

my $input= 'urxn';
my $output= 'D';
my $dryrun= 1;
my $cnt= -1;
my $block_size= 1048576;
my $mb_count= 4;
my $in_mem= 0;

my @PAR= ();
while (my $arg= shift (@ARGV))
{
     if ($arg eq '--') { push (@PAR, @ARGV); }
  elsif ($arg =~ /^--(.+)/)
  {
    my ($opt, $val)= split ('=', $1, 2);

       if ($opt eq 'count') { $cnt= $val; }
    elsif ($opt eq 'doit')  { $dryrun= 0; }
    elsif ($opt eq 'dryrun' || $opt eq 'dry-run') { $dryrun= 1; }
    elsif ($opt eq 'output') { $output= $val || shift (@ARGV); }
    elsif ($opt eq 'bs') { $block_size= $val || shift (@ARGV); }
    elsif ($opt eq 'mb') { $mb_count= $val || shift (@ARGV); }
    elsif ($opt eq 'mem') { $in_mem= 1; }
    else { usage(); }
  }
  elsif ($arg =~ /^-(.+)/)
  {
    my @opts= split ('', $1);
    foreach my $opt (@opts)
    {
         if ($opt eq 'c') { $cnt=    shift (@ARGV); }
      elsif ($opt eq 'i') { $input=  shift (@ARGV); }
      elsif ($opt eq 'o') { $output= shift (@ARGV); }
      elsif ($opt eq 'n') { $dryrun= 1; }
      else { usage(); }
    }
  }
  else { &usage; }
}

sub usage
{
  system ("perldoc $0");
  exit (0);
}

my $file_size= $block_size*$mb_count;
print "file_size=[$file_size]\n";
if (!-f $input || (stat(_))[7] < $file_size)
{ # create input file if it does not exist or is too small
  my @cmd= ('dd', 'if=/dev/urandom', "of=$input", "bs=$block_size", "count=$mb_count");
  print ">>> ", join (' ', @cmd), "\n";
  system (@cmd);
}

unless (-d $output)
{
  system ("mkdir $output");
}

my $buffer;
if ($in_mem)
{
  unless (open (FI, '<:raw', $input))
  {
    die "can not read input file '$input'";
  }
  sysread (FI, $buffer, $file_size);
}

my $start= time();
my $i= 0;
while (1)
{
  if ($cnt > 0 && $i >= $cnt)
  {
    print "count exceeded\n";
    last;
  }

  $i++;

  my $dest= sprintf ("%s/%08d.fillup", $output, $i);
  my @st;

  if (@st= stat ($dest))
  {
    print "destination [$dest] exists, skipping!\n";
    next;
  }

  my @c= ('cp', $input, $dest);

  if ($dryrun)
  {
    print join (' ', @c), "\n";
    if ($i >= 20)
    {
      print "enough for a dryrun!\n";
      last;
    }
  }
  else
  {
    if ($in_mem)
    {
      if (open (FO, '>:raw', $dest))
      {
        my $wr_size= syswrite (FO, $buffer, $file_size);
        if ($wr_size != $file_size)
        {
          print "write_size ($wr_size) does not match file_size ($file_size)\n";
          last;
        }
      }
      else
      {
        print "can not open to $dest; exiting\n";
        last;
      }
    }
    else
    {
      my $rc= system (@c);
      print join (' ', @c), ", rc='$rc'\n";
      if ($rc)
      {
        print "copy return code=[$rc]; stopping\n";
        last;
      }
    }
  }
}

my $finish= time();
print "start:  ", scalar localtime ($start), "\n";
print "finish: ", scalar localtime ($finish), "\n";
printf ("duration: %d seconds\n", $finish-$start);
