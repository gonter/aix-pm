
package Parse::CMD::lsof;

use strict;

use IPC::Run;

use Parse::ZonedTables;

sub get_lsof_list
{
  my ($in, $out, $err);
  my @cmd= qw(lsof -nP);
  IPC::Run::run (\@cmd, \$in, \$out, \$err);
  # print __LINE__, " out=[$out]\n";
  my @out= split("\n", $out);
  my $hdr= shift (@out);
  # print __LINE__, " hdr=[$hdr]\n";

  # V1:
  # my $fields= Parse::ZonedTables->new();
  # $fields->get_fields($hdr);

  # V2:
  my $fields= Parse::ZonedTables->get_fields($hdr);

  my @lines;
  my %pids;
  while (my $l= shift(@out))
  {
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

