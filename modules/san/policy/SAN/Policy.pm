# $Id: Policy.pm,v 1.11 2012/03/20 05:27:41 gonter Exp $

=pod

=head1 NAME

SAN Policy

=head1 SYNOPSIS

  use SAN::Policy;
  my $policy_file= '/etc/sanpolicy';
  my $policy= new SAN::Policy ('policy_file' => $policy_file, ... more options ...);

  my $policy_dump= 'tmp.policy.dump';
  $policy->refresh_policy ($policy_dump);

=head1 DESCRIPTION

This module is intended for the abstraction of a general SAN
environment, possibly consisting of several storages, switches,
fabrics, etc. possibly even by different vendors.

=cut

use strict;

package SAN::Policy;

use AIX::NIM::Config;
use Util::Simple_CSV;
use Data::Dumper;

# plugin modules
my %plugin_loaded= ();

=pod

=head2 new SAN::Policy (%options);

create a new policy object and set options:

 * policy_file   ... set name of policy file
 * system        ... specify name of storage specific plugins
 * get_spports   ... flag: retrieve storage processor FC port information

=cut

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj= {};
  bless $obj, $class;

  foreach my $par (keys %par)
  {
    $obj->{$par}= $par{$par};
  }

  $obj;
}

=pod

=head2 $policy->get_san_config ($p)

=cut

sub get_san_config
{
  my $xp= shift;
  my $p= shift;

  my $system= $xp->{'system'};

  if ($system eq 'EMC')
  {
    unless (defined ($plugin_loaded{'EMC'}) && $plugin_loaded{'EMC'})
    {
      require SAN::Policy::EMC;
      require EMC::CX;
      require EMC::log;
      $plugin_loaded{'EMC'}= time ();
    }

    get_EMC_san_config SAN::Policy::EMC ($xp, $p);
  }
  elsif ($system eq 'NetApp')
  {
    unless (defined ($plugin_loaded{'NetApp'}) && $plugin_loaded{'NetApp'})
    {
      require SAN::Policy::NetApp;
      require NetApp::FAS;
      # TODO: require NetApp::log;
      $plugin_loaded{'NetApp'}= time ();
    }

    # SAN::Policy::NetApp->get_NetApp_san_config ($xp, $p);
    get_NetApp_san_config SAN::Policy::NetApp ($xp, $p);
  }
}

=pod

=head2 $policy->pick_up ($nim_config, %what);

transcribe selected stanzas from the NIM config into the policy structure

=cut

sub pick_up
{
  my $xp= shift;
  my $policy= shift;
  my %what= @_;

  my @nim_objs= $policy->select_objects (%what);
  return undef unless (@nim_objs);
  my $nim_obj= (@nim_objs == 1) ? $nim_objs[0] : \@nim_objs;;

  my $label= join ('/', @_);

  foreach my $no (@nim_objs)
  {
    delete ($no->{'_'});
  }
  $xp->{'_nim_obj_'}->{$label}= $nim_obj;
}

=pod

=head2 $policy->load_csv ($csv_name);

load csv file named in policy file in "san_list" stanza

=cut

sub load_csv
{
  my $xp= shift;
  my $csv_name= shift;

  return undef unless (exists ($xp->{'_nim_obj_'})
                       && exists ($xp->{'_nim_obj_'}->{'class/policy/type/san_list'}));
  my $sl= $xp->{'_nim_obj_'}->{'class/policy/type/san_list'};
  my @csv_paths= $sl->av ($csv_name);
  return undef unless (@csv_paths);

  my $csv= new Util::Simple_CSV ('no_array' => 1);
  $csv->get_csv_file ($csv_paths[0]);
  # print "csv: csv_name=[$csv_name] csv_path=[$csv_paths[0]] ", Dumper ($csv);
  $xp->{'csv'}->{$csv_name}= $csv;
}

=pod

=head2 $policy->refresh_policy ([$dump_file])

reload the policy file, optionally, dump policy datastructure into $dump_file.

=cut

sub refresh_policy
{
  my $xp= shift;
  my $dump_file= shift;

  my ($POLICY_FILE, $policy_refresh)= map { $xp->{$_} } qw(policy_file policy_refresh);

  my @policy_stat= stat ($POLICY_FILE);

  return undef if ($xp->{'policy_mtime'} >= $policy_stat[9] && !$policy_refresh == 0);

## print "reading $POLICY_FILE\n";
  my $policy= new AIX::NIM::Config;  # prepare a fresh config object
  $policy->get_config ($POLICY_FILE);
  $xp->{'policy_mtime'}= $policy_stat[9];
  $policy_refresh= $xp->{'policy_refresh'}= time ();

  my $admin= $xp->pick_up ($policy, 'class' => 'policy', 'type' => 'san_admin');
  $xp->{'report_email'}= join (',', $admin->av ('notify_mail'));

  $xp->pick_up ($policy, 'class' => 'policy', 'type' => 'san_list');

  # retrieve information about FC storage processor ports
  if ($xp->{'get_spports'})
  {
    my %wwpns= ();
    my $spports= $xp->pick_up ($policy, 'class' => 'policy', 'type' => 'spport');
    foreach my $spport (@$spports)
    {
      # print "spport: ", Dumper ($spport);
      my $wwpn= $spport->{'wwpn'};
      $wwpn=~ s/://g;      # lspath data does not have colons
      $wwpn=~ tr/A-F/a-f/; # keep WWNs in lowercase
      $wwpns{$wwpn}= $spport;
    }
    $xp->{'paths'}= \%wwpns;
  }

  # extract san configuration data from policy file
  $xp->get_san_config ($policy);

  if ($dump_file)
  {
    if (open (DUMP, '>' . $dump_file))
    {
      print DUMP 'policy: ', Dumper ($policy), "\n";
      print DUMP 'admin: ', Dumper ($admin), "\n";
      print DUMP 'xp: ', Dumper ($xp), "\n";
      print __LINE__, " >> san config read, dumped to $dump_file\n";
      close (DUMP);
    }
  }

  $policy_refresh;
}

1;

=pod

=head1 BUGS

=head2 verify EMC dependency

This module was tightly related to the EMC::CX module.  There should be
a more modular approach where SAN::Policy doesn't have to know much
about a given storage system's specifica.  Otherwise, this should be
renamed to EMC::CX::Policy or similar.

=head2 only one system plugin possible

=head1 AUTHOR

Gerhard Gonter <g.gonter@cpan.org>

For more information, see http://aix-pm.sourceforge.net/

=over

