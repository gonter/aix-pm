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

my $tsv_fnm= 'data.tsv';
my @column_names;

my @PARS;
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg eq '--') { push (@PARS, @ARGV); @ARGV= (); }
  elsif ($arg =~ /^--(.+)/)
  {
    my ($opt, $val)= split ('=', $1, 2);

       if ($opt eq 'help') { usage(); }
    elsif ($opt eq 'out') { $tsv_fnm= $val || shift (@ARGV); }
    elsif ($opt eq 'col')
    {
      $val= shift (@ARGV) unless ($val);
      push (@column_names, split (',', $val));
    }
    else { usage(); }
  }
  elsif ($arg =~ /^-(.+)/)
  {
    foreach my $opt (split ('', $1))
    {
         if ($opt eq 'h') { usage(); exit (0); }
      # elsif ($opt eq 'x') { $x_flag= 1; }
      else { usage(); }
    }
  }
  else
  {
    push (@PARS, $arg);
  }
}

my @rows;
my %cols;

if (@PARS)
{
  foreach my $fnm (@PARS)
  {
    if (open (FI, '<:utf8', $fnm))
    {
      parse_stream(*FI, \@rows, \%cols);
      close (FI);
    } # TODO: else complain
  }
}
else
{
  parse_stream(*STDIN, \@rows, \%cols);
}

# print "rows: ", Dumper (\@rows);
# print "cols: ", Dumper (\%cols);

my $cols= (@column_names) ? \@column_names  : [ sort keys %cols ];
my $data= new Util::tsv('data', $cols, rows => \@rows);
# print "data: ", Dumper ($data);
# $data->{rows}= \@rows; print "data: ", Dumper ($data);
$data->save_tsv ($tsv_fnm);

exit(0);

sub usage
{
  system ('perldoc', $0);
  exit;
}

sub parse_stream
{
  local *F= shift;
  my $rows= shift;
  my $columns= shift;

  my $count= 0;
  LINE: while (my $l= <F>)
  {
    chop;
    next LINE unless ($l);
    # print ">> l=[$l]\n";
    my $data;

    eval { $data= from_json($l); };
    if ($@)
    {
      print "error: ", $@, "\n";
      next LINE;
    }
    # print "data: ", Dumper ($data);
    $count++;

    my %data2;
    flatten ($columns, '', \%data2, $data);
    push (@$rows, \%data2);
  }

  $count;
}

=head2 flatten ($columns, $prefix, $row, $data)

transcribe a hash structure $data into $row.  If elements of $data are hashes themselves, they are also folded into $row, where their column names are prefixed with the name of that element.

Example:

  { profile => "pha", key => "62538ff3b0caccafeece073070a394e0a1e9bc84", pid => "o:123456", job_data => { date => "Fri, 18 May 2018 00:01:01 +0200" } }

is transcribed into

  { profile => "pha", key => "62538ff3b0caccafeece073070a394e0a1e9bc84", pid => "o:123456", job_data_date => "Fri, 18 May 2018 00:01:01 +0200" }

=cut

sub flatten
{
  my $columns= shift;
  my $prefix= shift;
  my $row= shift;
  my $data= shift;

  foreach my $e (keys %$data)
  {
    my $c= $prefix . $e;
    my $d= $data->{$e};

    if (ref ($d) eq 'HASH')
    {
      # print "flattening $e\n";
      flatten ($columns, $c.'_', $row, $d);
    }
    else
    {
      $columns->{$c}++;
      $row->{$c}= $d;
    }
  }
}

__END__

=head1 TODO

 * option to specify output filename
 * option to specify column names in their expected order

