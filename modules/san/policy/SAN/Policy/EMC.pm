# $Id: EMC.pm,v 1.1 2012/01/30 11:32:34 gonter Exp $

package SAN::Policy::EMC;

# TODO: this should be pluggable or something similar
sub get_EMC_san_config
{
  my $mod= shift;
  my $xp= shift;
  my $p= shift;

  my $watch_list= $xp->{'watch_list'};

  my @e= $p->select_objects ('class' => 'policy', 'type' => 'san', 'system' => 'EMC');

  # read list of EMC SANS
  # print "e: ", join (' ', @e), "\n";
  my $emc_sps= $xp->{'emc_sps'}= {};
  my %emcs= ();
  EMC_system: foreach my $e (@e)
  {
    my $san= $e->{'san'};
    delete ($e->{'_'});

    ## print __LINE__, " storage system: ", join (' ', %$e), "\n";

    if (defined ($watch_list) && !exists ($watch_list->{$e->{'san'}}))
    {
      print "skipping $san\n";
      next EMC_system;
    }
    # print __LINE__, " san=[$san] e=", Dumper ($e), "\n";

    my ($name, $model, $comment, $cache)= map { ($e->av ($_))[0] } qw(_name_ model comments cache);
    ## print "cache='$cache'\n";

    my $supported= is_supported EMC::CX ($model);

    unless ($supported)
    {
      print "ATTN: model '$model' not yet supported\n";
      next;
    }

    my $emc= new EMC::CX ('name' => $name, 'model' => $model, 'comment' => $comment, 'cache' => $cache);
    $xp->{'emcs'}->{$name}= $emc;
    $emcs{$name}++;

    my @controller= $e->av ('controller');
    ## print "$name $model controller: " , join (', ', @controller), "\n";
    foreach my $ctrl (@controller)
    {
      &get_EMC_sp_config ($emc_sps, $p, $emc, $ctrl);
    }

  }

  @e= $p->select_objects ('class' => 'policy', 'type' => 'storagegroup');
  foreach my $e (@e)
  {
    ## print __LINE__, " storagegroup:: ", join (' ', %$e), "\n";
    my ($san, $project, $sg_name, $sg_uid, $comments)= map { ($e->av ($_))[0] } qw(san project sg_name sg_uid comments);

    next unless (exists ($emcs{$san}));  # only record data for storagegroups on EMC systems

    my $emc= $xp->{'emcs'}->{$san};
    my $sg= { 'project' => $project, 'sg_name' => $sg_name, 'sg_uid' => $sg_uid, 'comments' => $comments };
    $emc->{'storagegroups'}->{$sg_uid}= $sg;
  }
}

sub get_EMC_sp_config
{
  my $emc_sps= shift;
  my $p= shift;        # this is a NIM configuration (class NIM::Config)
  my $emc= shift;      # this is the object for the EMC storage device (class EMC::CX)

  my $name= shift;

  my $sp= $p->get_object ($name);
  my $ip= ($sp->av ('ip'))[0];

  my $c= $emc->new_controller ($name, 'ip' => $ip);

  push (@{$emc->{'_ip_'}}, $ip);

  my @spport= $sp->av ('spport');
  my %spport= ();
  my $emc_wwpn= $emc->{'wwpn'};

  foreach my $spport (@spport)
  {
    my $spp= $p->get_object ($spport); # spp is a NIM object (class NIM::Item)
    $spport{$spport}= $spp;

    if ($spp)
    {
      # $wwpn{$wwpn}->{'nim_obj'}= $spp;

      my $wwpn= $spp->av ('wwpn');
      my $zoning= $spp->av ('zoning');
      my $fabric= $spp->av ('fabric');
      my $link_status= $spp->av ('link_status');
      my $port_status= $spp->av ('port_status');
      # TODO: hmmm... what about wwnn or port base zoning?

      if ($wwpn)
      {
        my $x= $emc_wwpn->{$wwpn}=
        {
          'spport' => $spport,
          'controller' => $name,
          'nim_obj' => $spp,
	  'zoning' => $zoning,
          'fabric' => $fabric,
	  'link_status' => $link_status,
	  'port_status' => $port_status,
        };

	$x->{'alias'}= $spp->av ('wwpn_alias') if ($zoning eq 'wwpn');
      }
    }
  }

  $c->{'spport'}= \%spport;

  $emc_sps->{$name}=
  {
    'ip' => $ip,
    'log' => new EMC::log ($ip, 1),
  };
}

1;
