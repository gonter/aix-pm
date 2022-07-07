#!/usr/bin/perl
#
# $Id: readtoc.pl,v 1.1 2008/10/08 15:36:11 gonter Exp $
#

use strict;

use AIX::Software::toc;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $out_format= 'fs';
my $arg;
my @F= ();
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-fmt') { $out_format= shift (@ARGV); }
    else { &usage; exit (0); }
  }
  else
  {
    push (@F, $arg);
  }
}

foreach $arg (@F)
{
  &process_toc ($arg);
}

exit (0);

sub process_toc
{
  my $fnm= shift;

  my $obj= new AIX::Software::toc ();
  $obj->read_toc ($fnm);

  if ($out_format eq 'dd')
  {
    print Dumper ($obj), "\n";
  }
  elsif ($out_format eq 'toc')
  {
    print &print_toc ($obj), "\n";
  }
  elsif ($out_format eq 'fs')
  {
    &print_pkg_list ($obj);
  }
}

sub print_toc
{
  my $obj= shift;

  my $toc= $obj->{'_toc_'};

  foreach my $pkg (sort keys %$toc)
  {
    my $p_pkg= $toc->{$pkg};
    foreach my $fs (sort keys %$p_pkg)
    {
      my $p_fs= $p_pkg->{$fs};
      foreach my $ver (sort keys %$p_fs)
      {
	print join (':', $pkg, $fs, $ver), "\n";
      }
    }
  }
}

sub print_pkg_list
{
  my $obj= shift;

  print $obj->{'fnm'}, ":\n";
  foreach my $pkg (@{$obj->{'packages'}})
  {
    my ($pkg_name, $p_fs, $bff_name) = map { $pkg->{$_} } qw(pkg_name filesets bff_name);
    ## print "pkg_name=$pkg_name ($bff_name)\n";
    print $pkg_name, " ($bff_name):\n";
    &print_fs_list ($p_fs);
  }
}

sub print_fs_list
{
  my $p_fs= shift;

    foreach my $fs (@$p_fs)
    {
      my ($fs_name, $ver)= map { $fs->{$_} } qw(fset_name ver);
      ## print "fs_name=$fs_name ver=$ver\n";
      print join (' ', $fs_name, $ver), "\n";
    }
}

__END__

=pod

=head1 COPYRIGHT

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

See http://aix-pm.sourceforge.net/ for more information.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006..2008 by Gerhard Gonter

This program is free software; you can redistribute and/or modify it
under the same terms as Perl itself.

=over

