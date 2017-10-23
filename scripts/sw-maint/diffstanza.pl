#!/usr/local/bin/perl
# FILE %afs/etc/lib/GG/aix/diffstanza.pl
#
# written:       1998-08-17
# latest update: 2000-02-18 12:03:20
#

use AIX::System::Stanza;

$fnm1= shift (@ARGV);
$fnm2= shift (@ARGV);

$cfg1= new AIX::System::Stanza ($fnm1);
unless (defined ($cfg1))
{
  print "can't read $cfg1\n";
  exit (0);
}

$cfg2= new AIX::System::Stanza ($fnm2);
unless (defined ($cfg2))
{
  print "can't read $fnm2\n";
  exit (0);
}

&AIX::System::Stanza::cmp_stanza_db (*STDOUT, $cfg1, $cfg2);

__END__
print join (':', %$cfg), "\n";
foreach $stanza (sort keys %{$cfg->{stanza}})
{
  print "stanza: $stanza\n";
}

# $cfg->write_stances ('@@@');
