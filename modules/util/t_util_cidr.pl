#!/usr/bin/perl

use lib '.';

use Util::CIDR;
use Data::Dumper;
$Data::Dumper::Indent= 1;
$Data::Dumper::Sortkeys= 1;

my $uc= Util::CIDR->new();

$uc->add_cidr('111.121.0.0/16', 'blocked dv05');
$uc->add_cidr('111.122.0.0/16', 'just looking');
$uc->add_cidr('131.130.0.0/16', 'UNIVIE');
$uc->add_cidr('85.208.96.0/24', 'US crawlers');

foreach my $ip (qw(111.121.2.3 131.130.2.194 84.83.32.81 85.208.96.212 1.2.3.4))
{
  my $res= $uc->lookup($ip);
  print __LINE__, " ip=[$ip] res: ", Dumper($res);
}

print __LINE__, " uc: ", Dumper($uc);


