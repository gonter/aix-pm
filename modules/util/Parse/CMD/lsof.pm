
package Parse::CMD::lsof;

use strict;

use Parse::ZonedTables;

sub get_lsof_list
{
  open(LSOF, '-|', 'lsof') or die;
  my $hdr= <LSOF>; chop($hdr);

  # V1:
  # my $fields= Parse::ZonedTables->new();
  # $fields->get_fields($hdr);

  # V2:
  my $fields= Parse::ZonedTables->get_fields($hdr);

  my @lines;
  my %pids;
  while (my $l= <LSOF>)
  {
    chop($l);
    # print __LINE__, " lsof: l=[$l]\n";
    my $rec= $fields->match_fields($l);
    $rec->{_line}= $l; $rec->{_head}= $hdr; # used for debugging
    # print __LINE__, " rec: ", Dumper($rec);
    push (@lines, $rec);
    push (@{$pids{$rec->{PID}}->{$rec->{TID}}} => $rec);
  }
  close(LSOF);

  (\@lines, \%pids);
}

1;

