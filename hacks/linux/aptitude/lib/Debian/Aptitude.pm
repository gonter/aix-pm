#!/usr/bin/perl

=head1 NAME

  Debian::Aptitude;

=cut

package Debian::Aptitude;

use strict;

sub new
{
  my $class= shift;
  my $obj= {};
  bless $obj, $class;
  $obj;
}

sub parse
{
  my $p= shift;
  my $fnm= shift;

  open (FI, $fnm) or die;

  my @packages= ();
  my %packages= ();
  my $pkg= undef;

  while (<FI>)
  {
    chop;

    if (m#^([\w\-]+):\s+(.+)$#)
    {
      my ($an, $av)= ($1, $2);
      # print "an=[$an] av=[$av]\n";
      if ($an eq 'Package')
      {
        $pkg= {};
        push (@packages, $pkg);
      }

      if (defined ($pkg))
      {
        $pkg->{$an}= $av;
      }
      else
      {
        print "ATTN: no package defined [$_]\n";
      }
    }
    elsif (m#^$#)
    {
      $pkg= undef;
    }
    else
    {
      print "ATTN: unknown line format: [$_]\n";
    }
  }
  close (FI);

  # print "packages: ", main::Dumper (\@packages);

  \@packages;
}

1;

__END__

=head1 AUTHOR

  Gerhard Gonter <ggonter@cpan.org>

=cut

