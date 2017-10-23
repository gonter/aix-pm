#!/usr/bin/perl 

=head1 PURPOSE

Test script for the package Debian::Aptitude .

Reads /var/lib/aptitude/pkgstates and saves it in CSV format.

=cut

use strict;

use Util::Simple_CSV;

use Data::Dumper;
$Data::Dumper::Indent= 1;

use lib 'lib';
use Debian::Aptitude;

my $pkg_states= '/var/lib/aptitude/pkgstates';

my $p= new Debian::Aptitude;
my $pkgs= $p->parse ($pkg_states);
# print "p: ", Dumper ($p);

my @columns= (qw(Package Architecture Unseen State Dselect-State Remove-Reason));

my $csv= new Util::Simple_CSV('no_array' => 1);

$csv->define_columns(@columns);
print "csv: ", Dumper ($csv);

$csv->{'data'}= $pkgs;
sub check
{
  my ($array_ref, $hash_ref)= @_;
  # print "hr: ", Dumper($hash_ref);
  return ($hash_ref->{'State'} == 2) ? 1 : 0;
}

# $csv->filter(\&check);
# print "csv: ", Dumper ($csv);
$csv->sort('Package');

$csv->save_csv_file('filename' => 'packages.csv');

exit (0);

