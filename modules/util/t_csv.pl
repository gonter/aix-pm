#!/usr/bin/perl
# $Id: t_csv.pl,v 1.1 2008/07/25 16:03:06 gonter Exp $

use strict;

use Data::Dumper;

use Util::Simple_CSV;

$Data::Dumper::Indent= 1;

my $fnm= shift (@ARGV) or die "usage: $0 csv-file";

my $csv= new Util::Simple_CSV ();
$csv->load_csv_file ($fnm);

print Dumper ($csv), "\n";
