# $Id: NetApp.pm,v 1.2 2012/01/31 17:39:04 gonter Exp $

=pod

=head1 NAME

  package SAN::Policy::NetApp  --  provide access to SAN policy configuration for NetApp systems

=cut

package SAN::Policy::NetApp;

sub get_NetApp_san_config
{
  my $mod= shift;
  my $xp= shift;
  my $p= shift;

# print "mod=[$mod] xp=[$xp] p=[$p]\n";

  my $watch_list= $xp->{'watch_list'};

  my @n= $p->select_objects ('class' => 'policy', 'type' => 'san', 'system' => 'NetApp');
  # print "n: ", main::Dumper (\@n);

  # read list of NetApp SANS
  # print "e: ", join (' ', @e), "\n";
  my $netapp_sps= $xp->{'netapp_sps'}= {};
  my %netapps= ();
  NetApp_system: foreach my $n (@n)
  {
    my $san= $n->{'san'};
    delete ($n->{'_'});

    # print __LINE__, " storage system: ", join (' ', %$n), "\n";

    if (defined ($watch_list) && !exists ($watch_list->{$n->{'san'}}))
    {
      print "skipping $san\n";
      next NetApp_system;
    }
    # print __LINE__, " san=[$san] n=", main::Dumper ($n), "\n";

    my ($name, $model, $comment, $cache, $data_dir)= map { ($n->av ($_))[0] } qw(_name_ model comments cache data);
    print "cache='$cache'\n";

    my $supported= is_supported NetApp::FAS ($model);

    unless ($supported)
    {
      print "ATTN: model '$model' not yet supported\n";
      next;
    }

    my $netapp= new NetApp::FAS ('name' => $name, 'model' => $model, 'comment' => $comment, 'cache' => $cache, 'data' => $data_dir, 'nim_obj' => $n);
    $xp->{'netapps'}->{$name}= $netapp;
    $netapps{$name}++;

    my @controller= $n->av ('controller');
    ## print "$name $model controller: " , join (', ', @controller), "\n";
    foreach my $ctrl (@controller)
    {
      &get_NetApp_sp_config ($netapp_sps, $p, $netapp, $ctrl);
    }

  }

}

sub get_NetApp_sp_config
{
  my $netapp_sps= shift;
  my $p= shift;           # this is a NIM configuration (class NIM::Config)
  my $netapp= shift;      # this is the object for the EMC storage device (class EMC::CX)
  my $name= shift;

  my $sp= $p->get_object ($name);
  unless (defined ($sp))
  {
    print "sp undefined, name=[$name]\n";
    return undef;
  }

  delete ($sp->{'_'}); # throw away config line info
  my @ips= $sp->av ('ip');
  my $ip= (@ips) ? $ips[0] : '10.10.10.10';

  my $c= $netapp->new_controller ($name, 'ip' => $ip);
  $c->{'nim_obj'}= $sp;

  push (@{$netapp->{'_ip_'}}, $ip);

  my @spport= $sp->av ('spport');
  my %spport= ();
  my $netapp_wwpn= $netapp->{'wwpn'};

  foreach my $spport (@spport)
  {
    my $spp= $p->get_object ($spport); # spp is a NIM object (class NIM::Item)
    delete ($spp->{'_'});
# print "spport=[$spport] spp=[$spp] ", main::Dumper ($spp);
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
        my $x= $netapp_wwpn->{$wwpn}=
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

  $netapp_sps->{$name}=
  {
    'ip' => $ip,
    # 'log' => new NetApp::log ($ip, 1),
  };
}

1;

__END__

=head1 BUGS

heavily copied from SAN::Policy(::EMC)


=over
