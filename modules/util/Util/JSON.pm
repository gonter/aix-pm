
package Util::JSON;

use strict;

use JSON -convert_blessed_universally;

sub read_json_file
{
  my $fnm= shift;

  # BEGIN load JSON data from file content
  local $/;
  # print "reading config [$fnm]\n";
  open( my $fh, '<:utf8', $fnm ) or return undef;
  my $json_text   = <$fh>;
  close ($fh);
  # decode_json( $json_text ); # for some reason, decode_json() barfs when otherwise cleanly read wide characters are present
  from_json($json_text);
}

sub write_json_file
{
  my $json_fnm= shift;
  my $x= shift;

  print "json_fnm=[$json_fnm]\n";
  # print "x: ", main::Dumper ($x);

  my $json= new JSON;
  my $json_str= $json->allow_blessed->convert_blessed->encode($x);

  open (J, '>:utf8', $json_fnm) or die ("can not write to [$json_fnm]");
  syswrite (J, $json_str);
  close (J);

  1;
}

=head2 my $cfg_item= get_config_item ($cfg, $item)



=cut

sub get_config_item
{
  my $cfg= shift;
}

1;

__END__

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

