#!/usr/local/bin/perl
# FILE %usr/unixonly/aix/fixes.pl
#
# written:       1998-05-09
# latest update: 2000-01-26 21:12:40
#

use AIX::Software::Maintenance;

$obj= new AIX::Software::Maintenance (
  'base' => '/ftp/pub/systems/aix/fixes-v4'     # this should be configurable
);

$mode= 'U';
@AVAILABLE= ();
@INSTALLED= ();
@WANTED_FIXES= ();
$fnm_out= '';
$fix_format= 'fixdist';

ARGUMENT: while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg =~ /^-(I|A|U|F)/) { $mode= $1; }
    elsif ($arg eq '-o') { $fnm_out= shift (@ARGV); }
    elsif ($arg eq '-NI') { $obj->show_uninstalled (); }
    elsif ($arg eq '-NA') { $obj->show_unavailable (); }
    elsif ($arg eq '-PG') { $pg_list= &read_pg_list (shift (@ARGV)); }
    elsif ($arg eq '-WFL') { $WFL= 1; }
    elsif ($arg eq '-cdrom') { $fix_format= 'cdrom'; }
    elsif ($arg eq '-base') { $obj->{base}= shift (@ARGV); }
    else
    {
      &usage ($arg eq '-help' ? '' : "invalid argument '$arg'");
      exit (0);
    }
    next;
  }

     if ($mode eq 'I') { push (@INSTALLED, $arg); }
  elsif ($mode eq 'A') { push (@AVAILABLE, $arg); }
  elsif ($mode eq 'F') { push (@WANTED_FIXES, $arg); }
}

foreach $arg (@INSTALLED)
{
  $obj->read_lslpp ($arg);
}

foreach $arg (@AVAILABLE)
{
  $obj->read_installp ($arg);
}

   if ($fnm_out) { $obj->print_packages ($fnm_out); }
elsif ($pg_list) { &write_pg_files ($obj, $pg_list); }
else             { $obj->print_packages_FO (*STDOUT); }

if ($WFL)
{
  foreach $host (@WANTED_FIXES)
  {
    local (*FO);
    open (FO, ">$host.fixes") || die;
    print "writing fix list for $host to $host.fixes\n";
    $obj->list_necessary_fixes ($host, *FO, $fix_format);
    close (FO);
  }
}
exit (0);

# ----------------------------------------------------------------------------
sub write_pg_files
{
  my $obj= shift;
  my $pg_list= shift;

  my ($fnm, $pg);

  foreach $fnm (sort keys %$pg_list)
  {
    $pg= $pg_list->{$fnm};
    $obj->print_packages ($fnm, $pg);
  }

  my $rest= $obj->get_unreferenced_group ();

  $obj->print_packages ('_unref.html', $rest);
}

# ----------------------------------------------------------------------------
sub read_pg_list
{
  my $fnm= shift;
  my %pg_list;

  open (FI, "$fnm") || die;
  print "reading pg list from $fnm\n";

  while (<FI>)
  {
    chop;
    next if (/^#/);
    my ($fnm, $hl, $pl)= split (':');
    my @hl= split (',', $hl);
    my @pl= split (',', $pl);
    $pg_list{$fnm}=
    {
      'host_list' => \@hl,
      'package_list' => \@pl,
    };
  }
  close (FI);

  \%pg_list;
}

# ----------------------------------------------------------------------------
sub usage
{
  print <<END_OF_USAGE;
usage: $0 [-options] [filenanme]

Produce comparative package catalogs to compare fix levels available on
media against installed levels on one or more machines.

The listing is separated by package name containing each available
fileset belonging to that package, IF AND ONLY IF the package is
installed on at least one machine.

Options:
-I <fnm>+       ... listings in the format of 'lslpp -Lc all' output
-A <fnm>+       ... listings in the format of 'installp -L -d <device>'
-F <fnm>+       ... fix list for given hosts
-o <fnm>        ... output listing in HTML format
-NI             ... list also package that are not installed
-NA             ... list also package that are not available for fixing
-WFL            ... want fix list
-PG <fnm>       ... read package group list
-help           ... print help
-cdrom          ... assume input media is cdrom, otherwise fixdist mirror
-base <dir>     ... assume other base directory
END_OF_USAGE

  print "\nerror reason: ", join ("\n", @_), "\n" if (@_);
}
