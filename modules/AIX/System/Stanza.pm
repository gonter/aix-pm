#!/usr/local/bin/perl
# FILE %afs/etc/lib/GG/aix/AIX/System/Stance.pm
#
# treat a AIX stanza file as an Perl object
#
# written:       1998-08-17
# latest update: 2000-01-20 19:51:10
# $Id: Stanza.pm,v 1.5 2007/08/01 13:17:52 gonter Exp $
#

=pod

=head1 NAME

AIX::System::Stanza
AIX::System::Stanza::Entry
AIX::System::Stanza::Comment

=head1 DESCRIPTION

Parse and process stanzas which are used in AIX for various system
configuration files.

=head1 TODO

+ reconsider the naming of the objects: an individual entry is a stanza,
    not the whole file!
+ find a sepecific stanza
+ entries should be subclassed
+ method to insert a new entry after a certain Entry or Comment line

=cut

use strict;

# ----------------------------------------------------------------------------
package AIX::System::Stanza::Entry;

# ----------------------------------------------------------------------------
sub new
{
  my $class= shift;
  my $section= shift;

  my $entry=
  {
    'type' => 'stanza',
    'stanza' => $section,
    'attr' => {},
  };

  bless $entry, $class;

  $entry->set (@_);
  $entry;
}

# ----------------------------------------------------------------------------
sub add_ref
{
  my $entry= shift;
  my $ref= shift;

  $entry->set (@$ref);
}

# ----------------------------------------------------------------------------
sub add
{
  my $entry= shift;

  my $attr_hash= $entry->{'attr'};

  while (1)
  {
    my $attr= shift;
    my $value= shift;
    last unless (defined ($attr) && defined ($value));

    $attr_hash->{$attr}= $value;   
  }
}

# --------------------------------------------------------------------------------
sub get
{
  my $entry= shift;
  my $attr= shift;
  $entry->{attr}->{$attr};
}

# --------------------------------------------------------------------------------
sub set
{
  my $entry= shift;
  my $av;

  while (1)
  {
    my $attr= shift;
    last unless (defined ($attr));

    my $value= shift; # T2D: if value is not defined, delete it!
    # print "set: attr=$attr value=$value\n";

    $entry->{attr}->{$attr}= $value;
  }
}

# --------------------------------------------------------------------------------
sub print_stanza
{
  my $entry= shift;
  local *FO= shift;
  my $pfx= shift;

  print FO $pfx, $entry->{stanza}, ":\n";
  my $av= $entry->{attr};
  my $attr;
  # print ">>>> ", join (':', sort keys %$av), "\n";
  foreach $attr (sort keys %$av)
  {
    print FO $pfx, "\t", $attr, ' = ', $av->{$attr}, "\n";
  }
}

# --------------------------------------------------------------------------------
sub sprint_stanza
{
  my $entry= shift;
  my $pfx= shift;
  my $res;

  $res= $pfx . $entry->{stanza} . ":\n";
  my $av= $entry->{attr};
  my $attr;
  foreach $attr (sort keys %$av)
  {
    $res .= $pfx . "\t" . $attr . ' = ' . $av->{$attr} . "\n";
  }

  $res;
}

# ----------------------------------------------------------------------------
package AIX::System::Stanza::Comment;

# ----------------------------------------------------------------------------
sub new
{
  my $class= shift;

  my $entry=
  {
    'type' => 'comment',
    'txt' => [],
  };

  bless $entry, $class;
}

# --------------------------------------------------------------------------------
package AIX::System::Stanza;

=pod

=head1 PACKAGE

AIX::System::Stanza

=head1 SYNOPSIS

my $stanza= new AIX::System::Stanza ($filename, [$stanza_name]);

=cut

sub new
{
  my $class= shift;
  my $fnm= shift;
  my $name= shift || $fnm;
  my %more= @_;         # TOOD: copy attribute values into object

  my $obj=
  {
    'entries' => [],    # sequential list of entries including comments
    'stanza' => {},     # hashed entries, no comments
  };
  bless $obj, $class;

  $obj->{'name'}= $name if ($name);

  $obj->read_stanzas ($fnm) if ($fnm);
}

# --------------------------------------------------------------------------------

=pod

=head2 $stanza->insert_entry ($entry, [$postition])

Insert a new entry into the stanza file, either at the
position specified or at the end.

=cut

sub insert_entry
{
  my $obj= shift;
  my $entry= shift;
  my $position= shift;

  $obj->{stanza}->{$entry->{stanza}}= $entry
    unless ($entry->{type} eq 'comment');

  my $entries= $obj->{entries};
  if (defined ($position))
  {
    splice (@$entries, $position, 0, $entry);
  }
  else
  {
    push (@$entries, $entry);
  }
}

# --------------------------------------------------------------------------------

=pod

=head2 $stanza->read_stanzas ($filename)

Read stanzas from given file

=cut

sub read_stanzas
{
  my $obj= shift;
  my $fnm= shift;

  local *FI;
  $obj->{'fnm'}= $fnm;
  my $entries= $obj->{entries};
  my $stanza= $obj->{stanza};

  my $prev_section= '';
  my ($section, $value, $entry, $attr, $attr_hash, $txt);
  my $line= 0;
  open (FI, $fnm) || return undef;
  while (<FI>)
  {
    chop;
    $line++;

    if (/^\*/ || /^[ \t]*$/)
    {
      $section= 'comment';
      unless ($prev_section eq 'comment')
      {
        $entry= new AIX::System::Stanza::Comment;
        $txt= $entry->{'txt'};

        push (@$entries, $entry);
        $prev_section= 'comment';
      }
      push (@$txt, $_);
    }
    elsif (/^([\/\w\d\.\-\+]+):/) # ZZ
    {
      $section= $1;

      $entry= new AIX::System::Stanza::Entry ($section);

      $attr_hash= $entry->{'attr'};
      $obj->insert_entry ($entry);

      $prev_section= $section;
    }
    elsif (/^[ \t]+([\w\d\_\-]+)[ \t]*=[ \t]*(.*)/)
    {
      $attr= $1;
      $value= $2;
      $attr_hash->{$attr}= $value;   
    }
    elsif (/^([\w\d]+):[ \t]+([\w\d\_\-]+)[ \t]*=[ \t]*(.*)/)
    { # section: name=value
      ($section, $attr, $value)= ($1, $2, $3);

      $entry= new AIX::System::Stanza::Entry ($section);
      $obj->insert_entry ($entry);
      $prev_section= $section;

      $attr_hash= $entry->{'attr'};
      $attr_hash->{$attr}= $value;   
    }
    else
    {
      print "ATTN [$line] $_\n";
    }
  }
  close (FI);

  $obj;
}

# ----------------------------------------------------------------------------

=pod

=head2 $stanza->write_stanzas ($filename)

Write stanza objects to given filename.

=cut

sub write_stanzas
{
  my $obj= shift;
  my $fnm= shift;

  local *FO;
  open (FO, ">$fnm") || die;
  $obj->print (*FO);
  close (FO);
}

# ----------------------------------------------------------------------------

=pod

=head2 $stanza->print (*FileHandle)

Print stanza objects to given filehandle

=cut

sub print
{
  my $obj= shift;
  local *FO= shift;

  my $entries= $obj->{entries};
  my ($entry, $attr, $line);

  foreach $entry (@$entries)
  {
    if ($entry->{type} eq 'comment')
    {
      my $txt= $entry->{txt};
      ## print FO '*** COMMENT ****', "\n";
      foreach $line (@$txt)
      {
        print FO $line, "\n";
      }
    }
    elsif ($entry->{type} eq 'stanza')
    {
      ## print FO '*** STANAZA ****', "\n";
      $entry->print_stanza (*FO, '');
    }
  }
}

# --------------------------------------------------------------------------------
sub locate
{
  my $stanza= shift;
  my $entry= shift;
  $stanza->{'stanza'}->{$entry};
}

# --------------------------------------------------------------------------------
# search for the comment entry that contains a particular expression
# e.g.: $user->locate_comment ('*auth_method:');
sub locate_comment
{
  my $stanza= shift;
  my $string= shift;

  my ($entry, $t);
  foreach $entry (@{$stanza->{entries}})
  {
    next unless ($entry->{type} eq 'comment');
    my $txt= $entry->{txt};
    my $idx= 0;
    foreach $t (@$txt)
    {
      if ($t eq $string)
      {
        print ">>>> t='$t'\n";
        return ($entry, $idx);
      }
      $idx++;
    }
  }

  undef;
}

# --------------------------------------------------------------------------------
# compare two or more stanza databases
sub cmp_stanza_db
{
  local *DIAG= shift;
  my $s1= shift;
  my $s2= shift;

  my $st1= $s1->{stanza};
  my $st2= $s2->{stanza};

  my ($stanza, %stanza);
  foreach $stanza (keys %$st1)
  {
    $stanza{$stanza}= 1;
    unless (exists ($st2->{$stanza}))
    {
      $st1->{$stanza}->print_stanza (*DIAG, '< ');
      next;
    }

    &cmp_stanza (*DIAG, $stanza, $st1->{$stanza}, $st2->{$stanza});
  }

  foreach $stanza (keys %$st2)
  {
    next if (exists ($stanza{$stanza}));
    $st2->{$stanza}->print_stanza (*DIAG, '> ');
  }
}

# --------------------------------------------------------------------------------
# compare two or more stanzas
sub cmp_stanza
{
  local *DIAG= shift;
  my $stanza= shift;
  my $s1= shift;
  my $s2= shift;

  my $sa1= $s1->{attr};
  my $sa2= $s2->{attr};
  my ($attr, $sae1, $sae2, %attr);

  my $prt= 0;
  foreach $attr (keys %$sa1)
  {
    $attr{$attr}= 1;

    $sae1= $sa1->{$attr};
    unless (exists ($sa2->{$attr}))
    {
      unless ($prt) { print DIAG "| $stanza:\n"; $prt++; }
      print DIAG "< \t", $attr, ' = ', $sae1, "\n";
      next;
    }

    $sae2= $sa2->{$attr};
    if ($sae1 ne $sae2)
    {
      unless ($prt) { print DIAG "| $stanza:\n"; $prt++; }
      print DIAG "< \t", $attr, ' = ', $sae1, "\n";
      print DIAG "> \t", $attr, ' = ', $sae2, "\n";
    }
  }

  foreach $attr (keys %$sa2)
  {
    next if (exists ($attr{$attr}));

    $sae2= $sa2->{$attr};
    unless ($prt) { print DIAG "| $stanza:\n"; $prt++; }
    print DIAG "> \t", $attr, ' = ', $sae2, "\n";
  }
}

# ----------------------------------------------------------------------------
sub verify
{
  my $obj= shift;
  my $section= shift;
  my $ref_stanza= shift;        # what the stanza should look like
  my $comment= shift;           # use this comment to anchor new stanza

  my $st_ins= new AIX::System::Stanza::Entry ($section);
  $st_ins->add_ref ($ref_stanza);
  my $e= $obj->locate ($section);

    if (defined ($e))
    { # T2D: add verification function
      # $e->print_entry (*STDOUT);
      print ">>>> compare!\n";
      &cmp_stanza (*STDOUT, $section, $e, $st_ins);
    }
    else
    { # Stanza not present; see if the comment is there (cosmetics)

      my ($ref, $idx)= $obj->locate_comment ($comment);
      if (defined ($ref))
      { # comment is present, insert new text here
        print "idx=$idx ref=$ref\n";

        print ">>>> inserting info for $section after comment\n";
        my $str= $st_ins->sprint_stanza;
        print ">> str='$str'\n";

        splice (@{$ref->{txt}}, $idx+2, 0, $str);
      }
      else
      { # stanza not present, comment not present, append to file
        print ">>>> inserting info for $section at EOF\n";
        $obj->insert_entry ($st_ins);
      }
    }
}

# ----------------------------------------------------------------------------
1;

__END__

=pod

=head1 BUGS

Incomplete pod

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

see http://aix-pm.sourceforge.net/ for more information and news about this module

=over
