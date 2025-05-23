#!/usr/bin/perl
# $Id: csv.pl,v 1.51 2017/11/27 12:29:10 gonter Exp $

=pod

=head1 NAME

  csv [-options] filename+

  process csv files in some nice way

=head1 OPTIONS

=head2 --merge

merge the contents of the specified csv files

=head2 --out <filename>

write the (possibily merged) csv data into this file

=head2 --col name(,name*)

print data columns

=head2 --setcol name(,name*)

set column names.  useful when csv file does not start with column names.

=head2 --sort name

sort data by named column.  Useful for display and --out.

=head2 --num

sort column is numeric.

=head2 --hdr

print list of column names (CSV header)

=head2 -tchar ... CSV separator for input files

  char can be a single character or a specifier:
  wiki: try to read a table in wiki syntax

=head2 -Tchar ... CSV separator for the output file

=head2 -B(style) ... set border style

  none ..
  minimal ..
  default .. (similar to PostgreSQL)

=head2 other options

  -q .. strip quotes
  -x .. extended display mode
  --TAB .. switch to TSV mode

=head2 --max <num>

  only display this many items

=head2 searching

  --select <field>=<value>
  --find <pattern>
  --in <field> <value-1> .. <value-n>

=cut

use strict;

BEGIN { my @b= split ('/', $0); pop @b; unshift (@INC, join ('/', @b, 'perl')); }

use Util::Simple_CSV;
use Util::Matrix;
use Util::JSON;
use JSON;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $DUMP_FILE;
my $CSV_SEP= ';';
my $CSV_OUT_SEP;
my $op_mode= 'cat';
my $show_header= 0;
my $UTF8= 0;
my $out_file;
my @show_columns;
my @sort_columns;
my @set_columns;
my $sort_numeric= 0;

my $strip_quotes= 0;
my $view= 'matrix'; # values: matrix, extended, header, json, dumper
my $all= 0; # for extend view, sofar...
my $find_pattern= undef;   # this is used for a pattern match
my $search_string= undef;  # this is used to select a certain value in a column
my $skip= undef;

# used for option --in <fieldname> <field_value>+
my @search_strings;
my $search_field_name;

my $max_items;
my $json_file_to_load;

sub set_utf8 { $UTF8= 1; binmode (STDIN, ':utf8'); binmode (STDOUT, ':utf8'); }
sub usage { system ("perldoc '$0'"); exit (0); }

my @PARS= ();
while (defined (my $arg= shift (@ARGV)))
{
     if ($arg eq '--') { push (@PARS, @ARGV); @ARGV=(); }
  elsif ($arg eq '-') { push (@PARS, $arg); }
  elsif ($arg =~ /^--(.+)/)
  {
    my ($opt, $val)= split ('=', $1, 2);

       if ($opt eq 'merge')  { $op_mode= 'merge'; $view= 'no'; }
    elsif ($opt eq 'dump')   { $DUMP_FILE=     $val || shift (@ARGV); }
    elsif ($opt eq 'out')    { $out_file=      $val || shift (@ARGV); }
    elsif ($opt eq 'skip')   { $skip=          $val || shift (@ARGV); }
    elsif ($opt eq 'find')   { $find_pattern=  $val || shift (@ARGV); } # TODO: allow multiple patterns!
    elsif ($opt eq 'search' || $opt eq 'select')
    { # TODO: allow multiple searches!
      $search_string= $val || shift (@ARGV);
      # print __LINE__, " search_string=[$search_string]\n";
    }
    elsif ($opt eq 'in')
    {
      $search_field_name= $val || shift (@ARGV);
    }
    elsif ($opt eq 'max')    { $max_items=     $val || shift (@ARGV); }
    elsif ($opt eq 'hdr')    { $view= 'header'; }
    elsif ($opt eq 'json')   { $view= 'json';   }
    elsif ($opt eq 'dumper') { $view= 'dumper'; }
    elsif ($opt eq 'Dumper') { $view= 'Dumper'; }
    elsif ($opt eq 'setcol') { push (@set_columns,  split (',', $val || shift (@ARGV))); }
    elsif ($opt eq 'col')    { push (@show_columns, split (',', $val || shift (@ARGV))); }
    elsif ($opt eq 'sort')   { push (@sort_columns, split (',', $val || shift (@ARGV))); }
    elsif ($opt eq 'num')    { $sort_numeric= 1; }
    elsif ($opt eq 'nsort')  { push (@sort_columns, split (',', $val || shift (@ARGV))); $sort_numeric= 1; }
    elsif ($opt eq 'TAB'    || $opt eq 'tab')   { $CSV_SEP= "\t"; }
    elsif ($opt eq 'UTF8'   || $opt eq 'utf8')  { set_utf8(); }
    elsif ($opt eq 'border' || $opt eq 'style') { Util::Matrix::set_border_style ($val); }
    elsif ($opt eq 'load-json') { $json_file_to_load= $val || shift (@ARGV); }
    elsif ($opt eq 'AWK')
    { # hmm... maybe this should be done in a completely different way
      Util::Matrix::set_header_style ('none');
      Util::Matrix::set_border_style ('none');
      Util::Matrix::set_border_inter ("\t");
    }
    else { usage(); }
  }
  elsif ($arg =~ /^-t(.+)$/) { $CSV_SEP= $1; $CSV_SEP= 'wiki' if ($CSV_SEP eq 'confluence'); $CSV_SEP= "\t" if ($CSV_SEP eq 'TAB'); }
  elsif ($arg =~ /^-T(.+)$/) { $CSV_OUT_SEP= $1; $CSV_OUT_SEP= "\t" if ($CSV_OUT_SEP eq 'TAB'); }
  elsif ($arg =~ /^-B(.*)$/) { Util::Matrix::set_border_style ($1); }
  elsif ($arg =~ /^-H(.*)$/) { Util::Matrix::set_header_style ($1); }
  elsif ($arg =~ /^-O(.+)$/) { $out_file= $1; }
  elsif ($arg =~ /^-(.+)/)
  {
    foreach my $opt (split ('', $1))
    {
         if ($opt eq 'q') { $strip_quotes= 1; }
      elsif ($opt eq 'a') { $all= 1; }
      elsif ($opt eq 'x') { $view= 'extended'; }
      elsif ($opt eq 'J') { $view= 'json'; }
      elsif ($opt eq 'M') { $view= 'matrix'; }
      elsif ($opt eq 'R') { $view= 'Redmine'; }
      elsif ($opt eq 'G') { $view= 'Gnome'; }
      elsif ($opt eq 'D') { $view= 'dumper'; }
      elsif ($opt eq '8') { set_utf8(); }
      elsif ($opt eq '9') { $CSV_SEP= "\t"; }
      elsif ($opt eq '0') { $CSV_SEP= "\0"; }
      else { usage(); }
    }
  }
  else
  {
    if (defined ($search_field_name))
    {
      push (@search_strings, $arg);
    }
    else
    {
      push (@PARS, $arg);
    }
  }

}

unless (@PARS)
{

=begin comment

  print <<EOX;
usage: $0 [-options] fnm
EOX
  exit (0);

=end comment
=cut

  push (@PARS, '-');
}

my $csv= new Util::Simple_CSV ('separator' => $CSV_SEP,
   'strip_quotes' => $strip_quotes,
   'UTF8' => $UTF8,
   # 'no_array' => 1
   );

$csv->{'no_body'}= 1 if ($view eq 'header');
if (@set_columns)
{
  $csv->define_columns (@set_columns);
  $csv->{'no_headings'}= 1;
}

# print __LINE__, " find_pattern=[$find_pattern] search_string=[$search_string]\n";

if (defined ($find_pattern))
{
print "procssing find_pattern=[$find_pattern]\n";
  my $re= qr/$find_pattern/i;

=begin comment

  # define search filter function
  my $filter=
    sub
    {
      # my $cols= shift; # print "cols: ", Dumper ($cols);

      my $row= shift;
      print "ROW: ", Dumper ($row);
      foreach my $f (@$row) { return 1 if ($f =~ m#$re#); };
      return 0;
    };

  $csv->set ('filter' => $filter);

=end comment
=cut

  # define search filter definition!
  # (This filter is defined *after* the columns were identified)
  sub fidef1
  {
      my $obj= shift;
      my $cols= $obj->{'columns'};
      # print "cols: ", Dumper ($cols);

      my $fidef=
        sub
        {
          my $row= shift;
          # print "ROW: ", Dumper ($row);
          foreach my $f (@$row) { return 1 if ($f =~ m#$re#); };
          return 0;
        };

    return $fidef;
  };

  $csv->set ('fidef' => \&fidef1);
}

if (defined ($search_string))
{
  my ($field_name, $field_value)= split ('=', $search_string, 2);
# print __LINE__, " procssing search_string=[$search_string] field_name=[$field_name] field_value=[$field_value]\n";

  # the filter is dynamically generated since the field number is only
  # known after the column names are identified!
  sub fidef2
  {
    my $obj= shift;
# print __LINE__, " in fidef2\n";

    my $cols= $obj->{'columns'};
    my $col= 0;
    my %cols= map { $_ => $col++ } @$cols;

    # print "cols: ", Dumper ($cols);
    # print "cols: ", Dumper (\%cols);

    my $sub= <<"EOX";
  my \$fidef= sub
  {
    my \$row= shift;
    return (\$row->[$cols{$field_name}] eq '$field_value');
  };
EOX
    print STDERR "sub: [$sub]\n"; # if ($debug_level ... );
    my $res= eval ($sub);
    # print "res=[$res]\n";
    $res;
  };

  $csv->set ('fidef' => \&fidef2);
}
elsif (@search_strings)
{
  # the filter is dynamically generated since the field number is only
  # known after the column names are identified!

  sub fidef3
  {
    my $obj= shift;
# print __LINE__, " in fidef2\n";

    my $cols= $obj->{'columns'};
    my $col= 0;
    my %cols= map { $_ => $col++ } @$cols;

    # print "cols: ", Dumper ($cols);
    # print "cols: ", Dumper (\%cols);
  my %fidef3= map { $_ => 1 } @search_strings;
  print STDERR __LINE__, " fidef3: ", main::Dumper (\%fidef3);

    my $sub= <<"EOX";
  my \$fidef= sub
  {
    my \$row= shift;
    return (exists (\$fidef3{\$row->[$cols{$search_field_name}]}));
  };
EOX
    print STDERR "sub: [$sub]\n"; # if ($debug_level ... );
    my $res= eval ($sub);
    # print "res=[$res]\n";
    $res;
  };

  $csv->set ('fidef' => \&fidef3);
}

$csv->set ( max_items => $max_items ) if (defined ($max_items));
$csv->set ( skip => $skip ) if (defined ($skip));

my $fnm= shift (@PARS);
$csv->load_csv_file ($fnm);

exit (0) unless defined ($csv);
# print "csv: ", Dumper ($csv); exit (0);

while (my $fnm= shift (@PARS))
{
  $csv->merge_csv_file ($fnm);
}

my @columns;

if (defined ($json_file_to_load))
{
  my $data= Util::JSON::read_json_file ($json_file_to_load);

  my $csv2= clone Util::Simple_CSV($csv);
  $csv2->load_csv_data($data);

  $csv2->save_csv_file ('filename' => '@json_data.tsv',
           'separator' => ((defined ($CSV_OUT_SEP)) ? $CSV_OUT_SEP : $CSV_SEP));

  if (defined ($csv->{columns}))
  {
    $csv->merge($csv2, $csv->{no_array}, $csv->{no_hash});
  }
  else
  {
    $csv= $csv2;
    print STDERR "NOTE: using csv2\n";
    print "csv2: ", Dumper ($csv2);
    @columns= @{$csv->{columns}};
  }
}

# print "cols=", Dumper ($csv->{'columns'}), "\n";

# ---------------------------------------------------------------------
# Set up the list of columns which are then used or saved
# If a list of columns is defined via --col <name>[,<name>]*, then this
# is used, otherwise the list of columns is taken from the CSV file
# itself.
# <name> should come from the list of available columns, but it does
# not have to, e.g. when a CSV file should receive an empty new column
# for later filling in.
# If <name> is '*', then all unused available columns are added to
# the end.
# The same column name can be added multiple times in the --col option;
# we assume, the users knows what they do.
# ---------------------------------------------------------------------
if (!@columns)
{
  my @available_columns= @{$csv->{columns}} if (exists ($csv->{columns}) && defined ($csv->{columns}));
  if (@show_columns)
  {
    my %inserted;
    my $show_rest_too= 0;

    foreach my $c (@show_columns)
    {
      if ($c eq '*') { $show_rest_too= 1; next; }
      push (@columns, $c);
      $inserted{$c}= 1;
    }

    if ($show_rest_too)
    {
      foreach my $c (@available_columns)
      {
        push (@columns, $c) unless ($inserted{$c});
      }
    }
  }
  else
  {
    @columns= @available_columns;
  }
}
# print __LINE__, " columns: ", join(' ', @columns), "\n";

if (@sort_columns)
{
  $csv->sort ($sort_columns[0], 0, $sort_numeric);
}

my $d;
if ($view eq 'matrix' || $view eq 'Redmine' || $view eq 'Gnome')
{
  if ($out_file)
  {
    $d= $csv->get_columns (@columns);
    my $lines= Util::Matrix::save_as_csv (\@columns, $d, $out_file, ((defined ($CSV_OUT_SEP)) ? $CSV_OUT_SEP : $CSV_SEP), undef, undef, $UTF8);
    print STDERR "$lines saved to $out_file\n";
    $out_file= undef;
  }
  else
  {
    Util::Matrix::set_border_style ($view);
    $csv->matrix_view(\@columns);
  }
}
elsif ($view eq 'extended')
{
  $csv->extended_view (\@columns, $all);
}
elsif ($view eq 'header')
{
  $csv->show_header (*STDOUT);
}
elsif ($view eq 'json')
{
  my $json= JSON->new->allow_nonref;
  my $json_str= $json->pretty->encode ($csv->{'data'});
  print $json_str;
}
elsif ($view eq 'Dumper')
{
  print Dumper($csv);
}
elsif ($view eq 'dumper')
{
  print Dumper($csv->{'data'});
}
elsif ($view eq 'no')
{
  # dont show anything
}
else
{
  print "unknown view mode: [$view]\n";
  usage();
}

if ($out_file)
{
print "saving...\n";
  $csv->save_csv_file ('filename' => $out_file,
           'separator' => ((defined ($CSV_OUT_SEP)) ? $CSV_OUT_SEP : $CSV_SEP));
}

if ($DUMP_FILE)
{
  local *DUMP_FILE;
  open (DUMP_FILE, '>' . $DUMP_FILE) or die;
  print DUMP_FILE 'csv=', Dumper ($csv), "\n";
  if (defined ($d))
  {
    print DUMP_FILE "\n", 'd=', Dumper ($d), "\n";
  }
  close (DUMP_FILE);
}
exit (0);

__END__

=head1 Copyright

Copyright (c) 2006..2019 Gerhard Gonter.  All rights reserved.  This
is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

=head1 SEE ALSO

For more information, see http://aix-pm.sourceforge.net/

=head1 TODO

  * sort function (either just for output or data in-place)
  * allow "extended" output similar to pgsql \x style (mostly done)
  * column renaming similar to "SELECT bli AS bla FROM ..."

=head2 find(), search(), filter(), fidef()

add find() method to filter for certain patterns; there could be several
variants:

Specify a regular expression which is evaluated on each row while it
is read; matching rows are either tagged or otherwise only those are
added to the datastructure in memory.  Tagging can be done by adding a
virtual column of some name.  This virtual column could also be handled
in the same fashing as the rest of the data.

Furthermore, something that resembles a WHERE clause would be nice.
Together with tagging, this would be a powerful feature.

Also: Add a method to tag (not just filter) rows via callback...

Uh... that's getting complex!

=head2 --load-json

This is not yet working properly.  Right now, it is called like this:

  tsv --load-json nodes.json dummy.tsv 

dummy.tsv should not exist; the result is a TSV file named @json_data.tsv

