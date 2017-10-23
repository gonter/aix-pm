#!/usr/local/bin/perl
# FILE %afs/etc/lib/GG/aix/fixdiff.pl
#
# written:       2000-01-26
# latest update: 2000-01-26 21:36:52
# $Id: fixdiff.pl,v 1.2 2007/09/25 11:41:59 gonter Exp $
#

use AIX::Software::Maintenance;

$obj= new AIX::Software::Maintenance;

ARGUMENT: while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    # else
    {
      &usage ($arg eq '-help' ? '' : "invalid argument '$arg'");
      exit (0);
    }
    next;
  }

  push (@INSTALLED, $arg);
}

foreach $arg (@INSTALLED)
{
  $obj->read_lslpp ($arg);
}

# experimental features
my ($missing1, $missing2)= $obj-> _list_missing_filesets ($INSTALLED[0], $INSTALLED[1]);

my $prt_missing= fileset_string ($missing1);



if ($prt_missing)
{
  $cmd= "/usr/lib/instl/sm_inst installp_cmd -a -Q -d '.' -f '"
        . $prt_missing
        . "' '-c' '-N' '-g' '-X'   '-G' '-V2'";

  $fnm_out= $INSTALLED[1].'.missing';
  print "$fnm_out:\n", $cmd, "\n";
  open (BAT, ">$fnm_out") || die;
  print BAT $cmd, "\n";
  close (BAT);
}

open (FO, '>' . 'xxxfilesets') or die;
foreach my $x (@$missing2)
{
  print FO join (':', @$x), "\n";
}
close (FO);

exit (0);

# ------------------
# this should bring a nice list in the format
#   @@fileset level[,@@fileset level]*
sub fileset_string
{
  my $ref= shift;  # ref= [[fileset, level]*]
  my @res;

  foreach $fs_ref (@$ref)
  {
    my ($fs, $lev)= @$fs_ref;
print __LINE__, " fs='$fs' lev='$lev\n";

    my @lev= split (/\./, $lev);
    pop (@lev); push (@lev, '0');
    my $lev_used= join ('.', @lev);
    push (@res, '@@'.$fs.' '.$lev_used);
  }
  join (",", @res);
}

__END__


