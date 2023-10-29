
package Parse::ZonedTables;

# TODO: this is not a good nme, find something better!

use strict;

# use Data::Dumper;

sub new
{
  my $class= shift;
  my $self= bless({}, $class);
  $self;
}

sub get_fields
{
  my $self= shift;
  my $header= shift;

  my $r= ref($self);
  # print __LINE__, " r=[$r] self=[$self]\n";
  $self= new($self) if ($r eq '');

  my $lng= length($header);
  my $st= 0;
  my $word;
  my @header= ();
  my $field_num= 0;
  for (my $i= 0; $i < $lng; $i++)
  {
    my $c= substr($header, $i, 1);
    # print __LINE__, " i=[$i] c=[$c] st=[$st]\n";

    if ($c ne ' ' && $st == 0) # new word
    {
      push(@header, $word= { label => $c, idx => $i, field_num => $field_num++ });
      $st= 1;
    }
    elsif ($c ne ' ' && $st == 1) # next char of same wor
    {
      $word->{label} .= $c;
    }
    elsif ($c eq ' ' && $st == 1)
    {
      $st= 0;
    }
  }

  # print __LINE__, " header: ", Dumper(\@header);

  # (wantarray) ? @header : \@header;
  $self->{fields}= \@header;

  $self;
}

sub match_fields
{
  my $self= shift;
  my $l= shift;

  my $fields= $self->{fields};

  my $last_field_num= $#$fields;
  # print __LINE__, " last_field_num=[$last_field_num]\n";
  # match fields right to lef
  my $last_idx= length($l);
  my %rec;
  for (my $i= $last_field_num; $i >= 0; $i--)
  {
    my $f= $fields->[$i];
    my ($idx, $label)= map { $f->{$_} } qw(idx label);

    my $str= substr($l, $idx, $last_idx-$idx);
    # there can be right-flushed fields, e.g. PID from lsof, so check, if there is something to the left of from the index of that label and add it to the string, if necessary
    while ($idx > 0 && (my $x= substr($l, $idx-1, 1)) ne ' ')
    {
      $str= $x . $str;
      $idx--;
    }
    $str =~ s#^ *##; $str =~ s# *$##; # remove padding blanks from the begin and end

    $rec{$label}= $str;
    # print __LINE__, " field i=[$i] idx=[$idx] last_idx=[$last_idx] label=[$label] str=[$str] f: ", Dumper($f);
    $last_idx= $idx;
  }

  (wantarray) ? %rec : \%rec;
}

1;

