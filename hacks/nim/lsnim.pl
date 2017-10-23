#!/usr/bin/perl
# $Id: lsnim.pl,v 1.1 2008/12/09 16:47:21 gonter Exp $

=pod

=head1 lsnim.pl

This script modifies the behaviour of the lsnim command.

Output of "lsnim -t lpp_source" is sorted which makes it easier to
navigate on NIM clients when performing software maintenance.

=head1 installation

This script should be found as /usr/sbin/lsnim.pl

mv -i /usr/sbin/lsnim /usr/sbin/lsnim.bin
ln -s /usr/sbin/lsnim.pl /usr/sbin/lsnim

=cut

use strict;

my $bin= '/usr/sbin/lsnim.bin';

if ($ARGV[0] eq '-t' && $ARGV[1] eq 'lpp_source')
{
  system ("$bin -t lpp_source | sort");
}
else
{
  exec $bin, @ARGV;
}
