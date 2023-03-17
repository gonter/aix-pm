#!/usr/bin/perl

package Util::path_tree;

use strict;

use Data::Dumper;

sub new { bless { root => [], paths => [] }, shift; }

sub add_path
{
  my $self= shift;
  my $path= shift;
  my $data= shift;
  my $split_char= shift || '/';

  # print __LINE__, " add_path: path=[$path]\n";
  push (@{$self->{paths}} => $path);

  my @path= split($split_char, $path);
  # print __LINE__, " path: ", Dumper(\@path);

  my ($fc, $idx, $depth)= $self->find_xx(\@path, 1);
  $fc->[$idx]->[2]= $data;
  # print __LINE__,  " add_path: path=[$path] idx=[$idx] depth=[$depth] fc: ", Dumper($fc);
  ($fc, $idx, $depth);
}

sub get_paths
{
  my $self= shift;

  (wantarray) ? @{$self->{paths}} : $self->{paths};
}

sub find_path
{
  my $self= shift;
  my $path= shift;
  my $split_char= shift || '/';

  print __LINE__, " find_path: path=[$path]\n";

  my @path= split($split_char, $path);
  # print __LINE__, " path: ", Dumper(\@path);

  my ($fc, $idx, $depth)= $self->find_xx(\@path);
  # print __LINE__,  " find_path: path=[$path] idx=[$idx] depth=[$depth] fc: ", Dumper($fc);
  ($fc, $idx, $depth);
}

sub find_xx
{
  my $self= shift;
  my $path= shift;
  my $insert= shift;

  my $cursor= $self->{root};
  my $idx= 0;
  my $last_cursor= $cursor;
  my $last_index= 0;
  my $depth= 0;
  PE: foreach my $pe (@$path)
  {
    $last_cursor= $cursor;
    # print __LINE__, " add_path: pe=[$pe] cursor: ", Dumper($cursor);
    # print __LINE__, " self: ", Dumper($self);
    my $c= @$cursor;
    # print __LINE__, " c=[$c]\n";
    foreach (my $i= 0; $i < $c; $i++)
    {
      $last_index= $i;
      my $ce= $cursor->[$i]->[0];
      # print __LINE__, " i=[$i] ce=[$ce] pe=[$pe]\n";
      if ($ce eq $pe)
      {
        $cursor= $cursor->[$i]->[1];
        last PE if (!$insert && @$cursor == 0);
        $depth++;
        next PE;
      }
    }

    return ($last_cursor, -1, $depth) unless ($insert);

    my $sub_pe= [ $pe, [] ];
    $last_index= @$cursor;
    push (@$cursor, $sub_pe);
    $cursor= $sub_pe->[1];
    $depth++;
    # print __LINE__, " self: ", Dumper($self);
  }

  ($last_cursor, $last_index, $depth);
}

1;

