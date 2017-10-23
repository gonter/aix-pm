#!/usr/bin/perl
# $Id: chfs.pl,v 1.6 2017/01/05 15:48:06 gonter Exp $

=pod

=head1 NAME

chfs.pl  --  change filesystem properties

=head1 USAGE

chfs.pl -a size=+I<n>I<S> F<path>

Write the commands necessary to expand the filesystem F<path> by adding
I<n> units of I<S> (K, M, G, T) bytes (1K= 1024 bytes).

=cut

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;

my @paths= qw(/usr/sbin /sbin);

my @PARS;
my $attr= ();
while (defined (my $arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
    if ($arg eq '-a')
    {
      my ($an, $av)= split ('=', shift (@ARGV), '2');
      $attr->{$an}= $av;
    }
  }
  else
  {
    push (@PARS, $arg);
  }
}

my $fs= &get_mount ();
## print 'fs=', Dumper ($fs), "\n";
## print 'attr=', Dumper ($attr), "\n";

my $fs_name= shift (@PARS) or &usage ('no fs name');

my $fs_p= $fs->{$fs_name};

&chfs ($fs_p, $attr);

exit (0);

sub usage
{
  my $msg= shift;
  print $msg, "\n";
  print <<EOX;
usage: $0 -a attr==value filesystem

attribs:
size=+3G

Examples:
  chfs.pl -a size=+5g /bla
EOX
  exit;
}

sub chfs
{
  my $fs_p= shift or &usage ('unknown fs');;
  my $attr= shift;

  if (exists ($attr->{'size'}))
  {
    my $sz= $attr->{'size'};
    if ($sz =~ /^\+?(\d+)[GM]$/)
    {
      my $dv= $fs_p->{'dev'};
      my $ty= $fs_p->{'type'};
      # hmm: /dev/mapper/uservg-user3lv
      my $lv_name;

      print "# dv=[$dv]\n";
      $dv=~ s/--/=/g;
      if ($dv =~ m#/dev/mapper/([\w=]+)-([\w=]+)$#)
      {
        my ($vg, $lv)= ($1, $2);
        $vg=~ s/=/-/g;
        $lv=~ s/=/-/g;
        print "# vg=[$vg] lv=[$lv]\n";
        $lv_name= join ('/', '/dev', $vg, $lv);
      }
      elsif ($dv =~ m#/dev/mapper/(base--os)-([\w]+)$#)
      {
        my ($vg, $lv)= ('base-os', $2); # Ubuntu :-/
        $lv_name= join ('/', '/dev', $vg, $lv);
        # TODO: is there a general rule about this name scheme?
      }
      else
      {
        print "device name '$dv' not recognized!\n";
        exit (1);
      }

      my $c1= &locate_binary ('lvextend') . " -L '$sz' '$lv_name'";
      my $c2;
      if ($ty eq 'ext3' || $ty eq 'ext4')
      {
        $c2= &locate_binary ('resize2fs') . " -p '$lv_name'";
      }
      elsif ($ty eq 'xfs')
      {
        $c2= &locate_binary ('xfs_growfs') . " '$lv_name'";
      }
      else
      {
        print "unknown filesystem type '$ty' for '$dv'\n";
        exit (3);
      }

      print "# perform these commands:\n";
      print $c1, "\n";
      print $c2, "\n";
    }
    else
    {
      &usage ("size not known '$sz'");
    }

  }
}

sub get_mount
{
  my @mount= split (/\n/, `/bin/mount`);
  my %fs= ();
  foreach my $l (@mount)
  {
    ## print "# >>> l='$l'\n";

# /dev/mapper/uservg-user0lv on /u/user0 type ext3 (rw,_netdev,acl,usrquota,grpquota)
    if ($l =~ /^(\S+)\s+on\s+(.+)\s+type\s+(\S+)\s+\(([^)]+)\)$/)
    {
      my ($dev, $fs, $ty, $opts)= ($1, $2, $3, $4);
      my @opts= split (/,/, $opts);
      $fs{$fs}=
      {
        'dev'  => $dev,
        'fs'   => $fs,
        'type' => $ty,
        'opts' => \@opts,
      };
    }

  }

  \%fs;
}

sub locate_binary
{
  my $cmd= shift;

  foreach my $path (@paths)
  {
    my $bin= join ('/', $path, $cmd);
    return $bin if (-x $bin);
  }

  print "$cmd not found\n";
  exit (1);
  # return undef;
}

__END__

=pod

=head1 TODO

=head2 VG names

Ubuntu uses a VG named "F<base-os>" for the volume group where it's root
filesystem resides.  In the F</dev/mappper/> directory, this becomes
"F<base--os>".  Is this generally handled this way?  If so, the matching
pattern needs to be modified.

=head2 doit

The script should possibly really perform the steps in a controlled
manner.

=cut

