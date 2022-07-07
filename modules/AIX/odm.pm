#
# FILE odm.pm
#
# simple interface for AIX odm commands
#
# $Id: odm.pm,v 1.5 2011/12/18 10:50:16 gonter Exp $
#

use strict;

package AIX::odm;

=pod

=head1 NAME 

AIX::odm  --  simple AIX ODM operations

=head1 SYNOPSIS

use AIX::odm;

=head2 AIX::odm::change ($odm_class, $query, $data);

change ODM entries with data according to query

=head2 AIX::odm::add ($odm_class, $data);

add a new ODM entry

=head2 AIX::odm::get ($odm_class[, $query])

retrieve ODM entries that match optional query
returns array of lines or array reference

=cut

my $VERSION= 0.02;

sub change
{
  my $odm_class= shift;
  my $query= shift;
  my $data= shift;

  &operation ('odmchange', $odm_class, $data, 1, $query);
}

sub add
{
  my $odm_class= shift;
  my $data= shift;
  &operation ('odmadd', $odm_class, $data);
}

sub operation
{
  my $op= shift;
  my $odm_class= shift;
  my $data= shift;
  my $use_o= shift;
  my $query= shift;

  my @add= ();
  push (@add, "$odm_class:");
  my $k;
  foreach $k (sort keys %$data)
  {
    push (@add, "  " . $k . ' = "' . $data->{$k}. '"');
  }
  push (@add, '');

  my $cmd= $op;
  $cmd .= " -o $odm_class" if ($use_o);
  $cmd .= " -q \"$query\"" if ($query);
  print __LINE__, " >> $cmd\n";

  local *ODM;
  open (ODM, "|$cmd") || die; # odmadd - is not allowd!
  foreach (@add)
  {
    print $_, "\n";
    print ODM $_, "\n";
  }
  close (ODM);
  print "ODM operation '$op' done, odm_class='$odm_class'\n";

  @add;
}

sub get
{
  my $odm_class= shift;
  my $query= shift;

  my $cmd= "odmget";
  $cmd .= " -q '$query'" if ($query);
  $cmd .= ' ' . $odm_class;

  print ">> cmd=[$cmd]\n";
  # print ">>>>", `$cmd`, "<<<<\n";
  unless (open (OG, $cmd . '|'))
  {
    print "ERROR: cant read from odmget [$cmd]\n";
    return undef;
  }

  my @res;
  my $stanza= undef;
  my $lnr= 0;
  while (<OG>)
  {
    chop;
    # print ">>> [$_]\n";
    $lnr++;

    if ($_ eq '') { $stanza= undef; }
    elsif (/^\s+(\S+)\s+=\s+"([^"]*)"$/
           || /^\s+(\S+)\s+=\s+(\d+)$/
	  )
    {
      my ($an, $av)= ($1, $2);
      if (defined ($stanza)) { $stanza->av ($an, $av); }
      else
      {
	print "ATTN: no stanza defined at $lnr [$_]\n";
      }
    }
    elsif (/^(\S+):$/)
    {
      my $cl= $1;
      $stanza= new AIX::odm::stanza ($cl);
      push (@res, $stanza);
    }
    else
    {
      print "ATTN: unmatched odm line at $lnr [$_]\n";
    }
  }

  (wantarray) ? @res : \@res;
}

sub parse
{
# print "parsing...\n";
  my $l;
  while (defined ($l= shift (@_)))
  {
    print ">>> $l\n";
  }
}

package AIX::odm::stanza;

sub new
{
  my $cl= shift;
  my $name= shift;

  my $o=
  {
    '_name_' => $name,
  };
  bless $o, $cl;
  $o;
}

sub av
{
  my $o= shift;
  my $an= shift;
  my $av= shift;

  my $res= $o->{$an};
  $o->{$an}= $av if (defined ($av));
  $res;
}

1;

__END__

=pod

=head1 BUGS

Unfinished.

=head1 COMPATIBILITY

This module needs the existence of the AIX ODM commands in their standard paths,
so using it on other platforms than AIX will most likely not work.

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over
