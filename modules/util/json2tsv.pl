#!/usr/bin/perl

=head1 USAGE

  cat data.json-lines | ./json2tsv.pl

Reads individual lines which *each* contain a separate json structure
and saves the data in TSV format.

This is useful to save data from MongoDB find() statement using
cut'n'paste.


=cut

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;
use JSON;
use Util::tsv;

my @PARS;
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg eq '--') { push (@PARS, @ARGV); @ARGV= (); }
  elsif ($arg =~ /^--(.+)/)
  {
    my ($opt, $val)= split ('=', $1, 2);
    if ($opt eq 'help') { usage(); }
    else { usage(); }
  }
  elsif ($arg =~ /^-(.+)/)
  {
    foreach my $opt (split ('', $1))
    {
         if ($opt eq 'h') { usage(); exit (0); }
      elsif ($opt eq 'x') { $x_flag= 1; }
      else { usage(); }
    }
  }
  else
  {
    push (@PARS, $arg);
  }
}

my $x= parse_stream(*STDIN);
# print "x: ", Dumper ($x);
$x->save_tsv ('data.tsv');

exit(0);

sub parse_stream
{
  local *F= shift;

  my @rows;
  my %columns;
  LINE: while (my $l= <F>)
  {
    chop;
    next LINE unless ($l);
    # print ">> l=[$l]\n";
    my $data;

    eval {
      $data= from_json($l);
    };
    if ($@)
    {
      print "error: ", $@, "\n";
      next LINE;
    }
    # print "data: ", Dumper ($data);
    push (@rows, $data);

    foreach my $e (keys %$data)
    {
      $columns{$e}++;
    }
  }

  my $cols= [ sort keys %columns ];
  my $res= new Util::tsv('data', $cols);
  # print "res: ", Dumper ($res);
  $res->{rows}= \@rows;

  $res;
}

__END__

=head1 TODO

 * option to specify output filename
 * option to specify column names in their expected order

