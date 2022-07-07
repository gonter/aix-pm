#!/usr/bin/perl
#
# Produce catalog contents of .bff files by simply calling
#   installp -L -d <filename.bff>
# but prepends filename in catalog.
# see usage
#
# written:       1999-06-14
my $Id= '$Id: lsbff.pl,v 1.7 2011/09/16 18:14:26 gonter Exp $';
#

=pod

=head1 NAME

lsbff.pl    ... show table of contents of .bff files

=head1 DESCRIPTION

AIX uses files with an extension of .bff (backup file format) for it's
native package management.  These files contain a table of contents in
the file lpp_name.  To display a one-line TOC line, the command
installp -L -d example.bff can be used.  That's exactly what this
script is doing in order to extract TOC information.  However, calling
installp for a lot of files just to grep for a certain line is quite
expensive (slow).  Therefore, this script is also used to maintain
catalogs of such TOC information where only those files are actually
processed which were note present before.  No attempt is made to find
*updated* files.

=cut

use strict;
use Data::Dumper;
$Data::Dumper::Indent= 1;

use AIX::Software::Catalog;

my $installp= '/usr/sbin/installp';

unless (-x $installp)
{
  print "$installp not executable, maybe you need root privileges.\n";
  exit (0);
}

my $catalog= '';           # catalog file to use
my $renew= 0;              # ignore existing catalog
# my $verbose= 0;            # chat
my $force= 0;              # force installp

my @JOBS;
my @DIRS;
my $drop_missing_files= 0;
my $do_rename= 0;
my $doit= 0;

my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-cat') { $catalog= shift; }
    elsif ($arg eq '-dc')
    {
      my $dc= shift;
      $dc=~ s#/*$##;
      $catalog= "$dc.cat";
      push (@DIRS, $dc);
      $AIX::Software::Catalog::drop_missing_files= 1;
    }
    elsif ($arg eq '-new') { $renew= 1; }
    elsif ($arg eq '-v') { $AIX::Software::Catalog::verbose++; }
    elsif ($arg eq '-d') { push (@DIRS, shift); $AIX::Software::Catalog::drop_missing_files= 1; }
    elsif ($arg eq '-rename') { $do_rename= 1; }
    elsif ($arg eq '-doit') { $doit= 1; }
    else { &usage; exit (0); }
    next;
  }
  push (@JOBS, $arg);
}

unless ($catalog) { &usage; exit (0); }

my $cat= new AIX::Software::Catalog;

unless ($renew) { $cat->load_catalog ($catalog); }

while ($arg= shift (@DIRS))
{
  push (@DIRS, $cat->process_dir ($arg));
}

foreach $arg (@JOBS)
{
  $cat->process_bff ($arg);
}

$cat->mk_fileset_cross_ref ($arg);

if ($do_rename)
{
  $cat->rename_bff_files ($doit);
}
$cat->save_catalog ($catalog);

&dump ($cat);
exit (0);

# ----------------------------------------------------------------------------
sub usage
{
  print <<EOX;
usage: $0 -cat <cat> [-opts] <fnm>+

Options:
-cat <cat>      catalog file name (REQUIRED) [see -dc]
-new            re-create the catalog
-dc <dc>        <dc> is a directory name, all bff's there are processed,
                <dc>.cat is used as catalog file

$Id
EOX
}

sub dump
{
  my $cat= shift;
  open (FO, '>@lsbff.dump') or return undef;
  print FO &Data::Dumper::Dumper ($cat), "\n";
  close (FO);
  1;
}

# ============================================================================
__END__

=pod

=head1 COPYRIGHT

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

See http://aix-pm.sourceforge.net/ for more information.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006..2011 by Gerhard Gonter

This program is free software; you can redistribute and/or modify it
under the same terms as Perl itself.

=over
