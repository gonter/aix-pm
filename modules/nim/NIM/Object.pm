#
# FILE AIX/NIM/Object.pm
#
# NIM Object data
#
# $Id: Object.pm,v 1.9 2010/07/20 12:21:29 gonter Exp $
#

=pod

=head1 NAME

AIX::NIM::Object -- Handle AIX NIM Object

=head1 SYNOPSIS

  use AIX::NIM::Object;
  my $nim= new AIX::NIM::Object;  # prepare NIM config object
  $nim->av (name);                # retrieve value of an attribute
  $nim->av (name, value);         # set new value of an attribute
  $nim->get_hostname (if-name);   # retrieve saved hostname

=head1 DESCRIPTION

=cut

use strict;

package AIX::NIM::Object;

my $VERSION= '0.06';

sub new
{
  my $class= shift;
  my $name= shift;
  my $obj=
  {
    '_name_' => $name,
    '_' => [],         # T2D: maybe we need the attributes in the order they appeared...
  };
  bless $obj, $class;
}

=pod

=head2 $obj->av (name)

Retrieve the attribute value for a given attribute name.

In array context, retrieve all values as an array.

In scalar context, retrieve just the first value.

=head2 $obj->av (name, value)

Add attribute value for given name.  Returns the number of
attribute values recorded in that object.

=cut

sub av
{
  my $obj= shift;
  my $an= shift;
  my $av= shift;

  # simple getter
  unless (defined ($av))
  {
    return undef unless (exists ($obj->{$an}));

    my $x= $obj->{$an};
    if (ref ($x) eq 'ARRAY')
    { # selected attribute has more than one value
      return (wantarray)
             ? @$x       # return array of values if that's what the caller wants
             : $x->[0];  # otherwise return just the first item
    }
    else
    { # there is only one value for this attribute yet
      if (wantarray)
      { # wrap into array, if caller expects an array
        my @x= ($x);
        return @x;
      }
      return $x; # otherwise, return just the value
    }
  }

  # setter
  push (@{$obj->{_}}, [$an, $av]);
  my $c= 0;
  if (exists ($obj->{$an}))
  {
    if (ref ($obj->{$an}) eq 'ARRAY')
    { # attributes are already an arry
      push (@{$obj->{$an}}, $av);
      $c= @{$obj->{$an}};
    }
    else
    { # second attribute to add, convert to array
      $obj->{$an}= [$obj->{$an}, $av];
      $c= 2;
    }
  }
  else
  {
    $obj->{$an}= $av;
    $c= 1;
  }

  $c;
}

=pod

=head2 get_hostname (if_name);

Retrieve hostname associated with specified interface.  If no
interface is specified, if1 is used.

=cut

sub get_hostname
{
  my $mo= shift;
  my $if_name= shift || 'if1';

  my $if_data= $mo->av ($if_name);
  # print "if_data='$if_data'\n";
  return split (' ', $if_data);
}

1;

__END__
# POD Section

=head1 Copyright

Copyright (c) 2006..2010 Gerhard Gonter.  All rights reserved.  This
is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

=head1 SEE ALSO

For more information, see http://aix-pm.sourceforge.net/

=cut

