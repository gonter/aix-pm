#!/usr/local/bin/perl

=pod

=head1 

Parsing Brocade Configuration Data, e.g. from output of typescript

=head1 usage

Save configuration data to a file by calling typescript

 $ typescript my-switch
 $ ssh admin@my-switch
 (login as usual)
 (on the FabOS prompt, type the following commands to retrieve data)

 cfgshow
 switchshow
 portname
 nsshow
 quit
 ^D

./cfgdump.pl my-switch

=cut

use lib '.';

use strict;

use Brocade::Config;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $config= new Brocade::Config;

my $fnm= shift (@ARGV) or die;
$config->parse_file ($fnm);
$config->fixup ();

if (open (FO, ">$fnm.DEBUG"))
{
  print FO 'config: ', Dumper ($config), "\n";
  close (FO);
}

$config->check_port_names ();

$config->zone_as_html ("$fnm.html", $fnm);
$config->portlayout_as_html ("$fnm-portlayout.html", $fnm);

exit (0);

