#!/usr/bin/perl
# $Id: vx_clean.pl,v 1.1 2011/12/18 11:57:33 gonter Exp $

=pod

=head1 NAME

  vx_clean.pl

=head1 USAGE

  vx_clean.pl -doit

=head1 DESCRIPTION

delete entries in the ODM class "vx_task" that are older than one year
and not describing an existing NIM mksysb object.

=cut

use strict;
use Data::Dumper;
$Data::Dumper::Indent= 1;
use AIX::NIM::Config;
use AIX::odm;
use Util::ts;

my $ODM_CLASS_vx_task= 'vx_task';
my $max_age= 366 * 1;
my $ts_max_age= &ts_ISO (time () - 86400 * $max_age);
print "ts_max_age=[$ts_max_age]\n";

my $doit= 0;

my %msb_objects= ();

while (my $arg= shift (@ARGV))
{
  if ($arg eq '-doit') { $doit= 1; }
}

&get_nim_mksysb_objects ();
&get_vx_task ($ODM_CLASS_vx_task);

&filter;

exit (0);

sub filter
{
  my @odm_delete_queue= ();
  foreach my $msb_name (sort keys %msb_objects)
  {
    my $o= $msb_objects{$msb_name};
    # print join (' ', $o, $msb_name, '[', (sort keys %$o), ']'), "\n";

    if (exists ($o->{'vx'}) && exists ($o->{'nim_obj'}))
    { # mksysb is present both as vx_task as well as in nim; this is a current backup
    }
    elsif (exists ($o->{'vx'}))
    { # mksysb is only known in vx_task, this is an expired backup, decide what to do
      # print "NOTE: expired msb_object [$msb_name]: ", Dumper ($o), "\n";
      push (@odm_delete_queue, @{$o->{'vx'}});
    }
    elsif (exists ($o->{'nim_obj'}))
    { # mksysb is only present in nim; this was done by hand, don't touch that stuff
    }
    else
    { # this can't happen, can it?
      print "ATTN: strange msb_object [$msb_name]: ", Dumper ($o), "\n";
    }
  }

  my $cnt_deleted= 0;
  foreach my $q (@odm_delete_queue)
  {
    # print "NOTE: expired vx_task: ", Dumper ($q), "\n";
    my ($task_id, $status, $par1, $par2, $ts_finished, $result)= map { $q->{$_}; } qw(task_id status par1 par2 ts_finished result);

    if ($ts_finished == 0)
    {
      print "ATTN: invalid timestamp: ", Dumper ($q), "\n";
    }
    elsif ($ts_finished lt $ts_max_age)
    {
      printf ("%-16s %-10s %-10s %5d %s %s\n", $task_id, $status, $ts_finished, $result, $par1, $par2);
      my $cmd_del= "odmdelete -o $ODM_CLASS_vx_task -q 'task_id=$task_id'";
      print "cmd_del=[$cmd_del]\n";

      if ($doit)
      {
        system ($cmd_del);
        $cnt_deleted++;
        # last;
      }
    }
  }

  print "cnt_deleted=$cnt_deleted\n";
}

sub get_nim_mksysb_objects
{
  my $nim= new AIX::NIM::Config ('verbose' => 1);
  $nim->get_type_config('mksysb');
  # print "nim: ", Dumper ($nim);

  my @names= $nim->get_object_names ();
  foreach my $name (@names)
  {
    my $nim_obj= $nim->get_object ($name);
    delete ($nim_obj->{'_'});
    # print "nim_obj: ", Dumper ($nim_obj);
    push (@{$msb_objects{$name}->{'nim_obj'}}, $nim_obj);
  }
}

sub get_vx_task
{
  my $odm_class= shift or die "no odm class specified";

  my $odm_vx= AIX::odm::get ($odm_class);
  # print "odm_vx: ", Dumper ($odm_vx);
  foreach my $vx (@$odm_vx)
  {
    # print "vx: ", Dumper ($vx);
    my ($par2, $task_id, $status)= map { $vx->{$_}; } qw(par2 task_id status);

    # printf ("%-16s %-16s %s\n", $task_id, $status, $par2); TODO if debug or so

    if (exists ($msb_objects{$par2}->{$vx}))
    {
      print "ATTN: msb_object [$par2] already defined!\n";
    }

    push (@{$msb_objects{$par2}->{'vx'}}, $vx);
  }
  
}

__END__

=head1 AUTHOR

Gerhard Gonter <ggonter@cpan.org>

See http://aix-pm.sourceforge.net/ for more information.

=over

