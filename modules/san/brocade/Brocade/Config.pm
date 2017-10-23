#!/usr/local/bin/perl
#
# $Id: Config.pm,v 1.40 2012/02/28 17:36:19 gonter Exp $
#

=pod

=head1 NAME

Brocade::Config  --  Brocade Switch Configuration Data

=head1 SYNOPSIS

=head1 DESCRIPTION

Process configuration data from Brocade FibreChannel switches.

=cut

package Brocade::Config;

use strict;
use Brocade::Config::Item;

my $Version= '0.04';

my %Known_Sections= map { $_ => 1 } qw(portname switchshow alishow cfgshow nsshow myid psshow fanshow sensorshow sfpshow);

my $CSV_SEPARATOR= ';';
my $CSV_FIELD_SEPARATOR= ' ';
my $PORTS_LAYOUT_27_2= # switchType 27.2: IBM 2005-H08
{
  'columns' => 4,
  'groups' => 1,
  'layout' =>
  [
    [ 0,  1,  2,  3,  ], # "board" 0
    [ 4,  5,  6,  7,  ], # "board" 1
  ]
};

my $PORTS_LAYOUT_26_2= # switchType 26.2: IBM 2005-H16
{
  'columns' => 8,
  'groups' => 1,
  'layout' =>
  [
    [ 0,  1,  2,  3,    8,  9, 10, 11,  ], # "board" 0
    [ 4,  5,  6,  7,   12, 13, 14, 15,  ], # "board" 1
  ]
};

my $PORTS_LAYOUT_34_0= # switchType 34.0: EMC blabla
{
  'columns' => 8,
  'groups' => 1,
  'layout' =>
  [
    [ 0,  1,  2,  3,    8,  9, 10, 11,  ], # "board" 0
    [ 4,  5,  6,  7,   12, 13, 14, 15,  ], # "board" 1
  ]
};

my $PORTS_LAYOUT_44_2= # switchType 44.2: Brocade 4800
{
  'columns' => 16,
  'groups' => 2,
  'layout' =>
  [
    [ 0,  1,  2,  3,    8,  9, 10, 11,   16, 17, 18, 19,   24, 25, 26, 27 ], # "board" 0
    [ 4,  5,  6,  7,   12, 13, 14, 15,   20, 21, 22, 23,   28, 29, 30, 31 ], # "board" 1
  ]
};

my $PORTS_LAYOUT_58_2= # switchType 58.2: Brocade 5000
{
  'columns' => 16,
  'groups' => 1,
  'layout' =>
  [
    [ 0,  1,  2,  3,    8,  9, 10, 11,   16, 17, 18, 19,   24, 25, 26, 27 ],
    [ 4,  5,  6,  7,   12, 13, 14, 15,   20, 21, 22, 23,   28, 29, 30, 31 ],
  ]
};

my $PORTS_LAYOUT_66_1= # switchType 66.1: ...
{
  'columns' => 20,
  'groups' => 1,
  'layout' =>
  [
    [ 0,  1,  2,  3,    8,  9, 10, 11,   16, 17, 18, 19,   24, 25, 26, 27,  32, 33, 34, 35, ],
    [ 4,  5,  6,  7,   12, 13, 14, 15,   20, 21, 22, 23,   28, 29, 30, 31,  36, 37, 38, 39, ],
  ]
};

# TODO: check correct layout of 42.2 type director blade
my $PORTS_LAYOUT_42_2= # switchType 42.2: Brocade 48000 directory FC blade
{
  'columns' => 16,
  'groups' => 1,
  'layout_1' => 'as blade',
  'x_layout' =>
  [
    [ 0,  1,  2,  3,    4,  5,  6,  7,   16, 17, 18, 19,   24, 25, 26, 27 ], # "board" 0
    [ 4,  5,  6,  7,   12, 13, 14, 15,   20, 21, 22, 23,   28, 29, 30, 31 ], # "board" 1
  ]
};

my $PORTS_LAYOUT=
{
  '26.2' => $PORTS_LAYOUT_26_2,
  '27.2' => $PORTS_LAYOUT_27_2,
  '34.0' => $PORTS_LAYOUT_34_0,
  '42.2' => $PORTS_LAYOUT_42_2, # does not work properly yet
  '44.2' => $PORTS_LAYOUT_44_2,
  '58.2' => $PORTS_LAYOUT_58_2,
  '66.1' => $PORTS_LAYOUT_66_1,
};

my $debug_level= 2;

sub new
{
  my $class= shift;

  my $obj=
  {
    'Defined_Configuration' => {},
    'Effective_Configuration' => {},
  };

  bless $obj, $class;

  $obj->set (@_);

  $obj;
}

sub set
{
  my $obj= shift;
  my %par= @_;

  my %res;
  foreach my $par (keys %par)
  {
    $res{$par}= $obj->{$par};
    $obj->{$par}= $par{$par};
  }

  (wantarray) ? %res : \%res;
}

sub get_array
{
  my $obj= shift;
  my @par= @_;

  my @res;
  foreach my $par (@par)
  {
    push (@res, $obj->{$par});
  }

  (wantarray) ? @res : \@res;
}

sub get_hash
{
  my $obj= shift;
  my @par= @_;

  my %res;
  foreach my $par (@par)
  {
    $res{$par}= $obj->{$par};
  }

  (wantarray) ? %res : \%res;
}

*get= *get_array;

sub debug_level
{
  my $res= $debug_level;
  $debug_level= shift;
  $res;
}

sub find
{
  my $obj= shift;
  my $type= shift;
  my $id= shift;

  my $x= $obj->{$type}->{$id};
  unless (defined ($x))
  {
    $x= $obj->{$type}->{$id}= new Brocade::Config::Item;
  }
  $x;
}

sub find_port_NOT_USED
{
  my $obj= shift;
  my $area= shift; # or slot
  my $port= shift;

  my $x= $obj->{'Slot'}->{$area}->{$port};
  unless (defined ($x))
  {
    $x= $obj->{'Slot'}->{$area}->{$port}= new Brocade::Config::Item;
  }
  $x;
}

sub parse_file
{
  my $obj= shift;
  my $fnm= shift;

  open (FI, $fnm) or return undef;

  my @f_st= stat ($fnm);
  $obj->{'file_date'}= $f_st[9];

  my @lines= <FI>;
  print "first_line=[$lines[0]]\n";
  close (FI);

  $obj->parse_lines (@lines);
}

sub parse_lines
{
  my $obj= shift;
  my @lines= @_;

  my $section= undef;
  my $section_count= 0;
  my $so= undef; # section object
  my $so_line= undef;
  my $cfg_obj= undef;
  my $node_o= undef;
  my $ps_obj= undef;

  local $_;
  while ($_= shift (@lines))
  {
    chop;

    s/\r//g;              # I'm not sure if chomp would get these ...
    s/\007//g;            # BELL
    while (s/.\010//) {}; # we are possibly parsing output from typesecript, so eliminate ^H-s
                          # NOTE: this is not the same as s/.\010//g; !
    s/\s*$//;             # no trailing blanks

    if (/^.+:admin> (.+)/)
    {
      my $cmd= $1;

      if (exists ($Known_Sections{$cmd}))
      {
        $section= $cmd;
        $section_count++;
        $ps_obj= undef;
      }
      elsif ($cmd =~ /portshow\s+([\/\d]+)/)
      {
        my $port_spec= my $port_index= $1;
        $section= 'portshow';

        if (exists ($obj->{'PS2PI'}))
	{
	  $port_index= $obj->{'PS2PI'}->{$port_spec};
        }

        my $port_obj= $obj->find ('Port' => $port_index);
        $so= $port_obj->{$section}= new Brocade::Config::Item;
        $so->{'_state_'}= 1;
## print 'port_obj: ', main::Dumper ($port_obj), "\n";
      }
      elsif ($cmd =~ /(portstats(64)?show)\s+([\/\d]+)/)
      {
        my $port_num= $3;
        $section= $1;

        my $port_obj= $obj->find ('Port' => $port_num);

        $so=
	{
          '_state_' => 1,
	  '_t_' => $section,
	  '_d_' => $port_obj->{$section}= [],
	  '_po_' => $port_obj,
        };

	# check if we already have a description of the statistics
	# structure, otherwise collect that information
        unless (exists ($obj->{'desc'}->{$section}))
	{
	  my $x= $obj->{'desc'}->{$section}= {};
	  $so->{'_list_'}= $x->{'list'}= [];
	  $so->{'_dict_'}= $x->{'dict'}= {};
        }
      }
      elsif ($cmd =~ /(sfpshow)\s+([\/\d]+)/)
      {
        $section= $1;
        my $port_spec= my $port_index= $2;

        # my $port_obj= $obj->find ('Port' => $port_num);

        if (exists ($obj->{'PS2PI'}))
	{
	  $port_index= $obj->{'PS2PI'}->{$port_spec};
        }

        # my $sfp_obj= $obj->find ('SFP' => $port_index);
        # $so= $sfp_obj->{$section}= new Brocade::Config::Item;
        $so= $obj->find ('SFP' => $port_index);

        $so->{'_state_'}= 1;
## print 'sfp_obj: ', main::Dumper ($sfp_obj), "\n";
      }
      else
      {
        $section= undef;
      }

      ## print __FILE__, ':', __LINE__, " command: '$cmd' => section='$section'\n";
    }
    elsif (defined ($section))
    {
      ## print __LINE__, " >> {$section} [$_]\n";

      if ($section eq 'portname')
      {
        if (/^port\s+(\d+):\s+(.+)/)
        {
          my ($num, $nam)= ($1, $2);
          # print __LINE__, " >>> num='$num' nam='$nam'\n";
          my $p= $obj->find ('Port', $num);
          $p->set ('name' => $nam, 'Index' => $num);
        }
      }
      elsif ($section eq 'portshow')
      {
        if ($_ eq '')
	{
	  $so->{'_state_'}= 1 if ($so->{'_state_'} == 2);
        }
        elsif ($so->{'_state_'} == 1)
        {
          if ($_ eq 'portWwn of device(s) connected:')
          {
            $so->{'_state_'}= 2;
            $so->{'portWwn of device(s) connected'}= [];
          }
          elsif (/^\s*(.+):\s*$/)
	  { # e.g. "/^portname:/$"
	    my $an= $1;
	    $so->{$an}= undef;
	  }
          elsif (/^\s*(.+):\s+(.*)/)
          {
            my ($an, $av)= ($1, $2);
            $so->{$an}= $av;

            if ($lines[0] =~ /.+:\s+.+:\s+.+/)
            { # after portSpeed or so we see a bunch of statistics data
              # encapsulate that into a separate Item;
# print __LINE__, " switch to state 3 [", $lines[0], "]\n";
              # my $x= new Brocade::Config::Item;
              # $so->{'_statistics_'}= $x;
              $so->{'_state_'}= 3;
            }
          }
          else
          {
            print __LINE__, " >>>>> portshow [$_]\n";
          }
        }
        elsif ($so->{'_state_'} == 2)
        {
# we are reading a list of WWPNs, in most cases there will only be one
# such address, but there may be more addresses, e.g. for L-Ports or
# NPIV:
# |portWwn of device(s) connected:
# |        21:78:00:c0:ff:0a:53:3f
# |        20:70:00:c0:ff:0a:53:3f
# |Distance:  normal

          $_=~ s/^\s*//;
          push (@{$so->{'portWwn of device(s) connected'}}, $_);

	  # check if next line begins with blanks, this means there are
	  # still more addresses to read:
          $so->{'_state_'}= 1 unless ($lines[0] =~ /^\s+/);
        }
        elsif ($so->{'_state_'} == 3)
	{
	  if (m#CMI_bus_err#)
	  {
            $so->{'_state_'}= 1;
	    # print "so: ", main::Dumper ($so), "\n";
	  }
	  # print ">>> [$_]\n";
	  s#([^:]+):\s+(\d+)\s*#{ my ($an, $av)= ($1, $2); $an=~ s/\s*$//; $so->{$an}= $av; "[$an]{$av}"; }#ge;
	  # print "<<< [$_]\n";
	}
        elsif (0 && $so->{'_state_'} == 3)
        { # statistics section?
          my @f= split (/: +/);
          while (defined (my $an= shift (@f)) && defined (my $av= shift (@f)))
          {
            # last unless ($an);
            $av=~ s/ *$//;
            # $an=~ s/:$//;
            $so->{$an}= $av;
print "an=[$an] av=[$av]\n";
            $so->{'_state_'}= 1 if ($an eq 'CMI_bus_err');
          }
        }
        else
        {
          print __LINE__, " >>>>> portshow [$_]\n";
        }
      }
      elsif ($section eq 'portstatsshow')
      {
        if ($_ =~ m#^(\w+)\s+(\d+)\s+(.+)#)
	{
	  &save_counter ($so, $1, $2, $3);
	}
	elsif ($_ =~ m#^tim_txcrd_z_vc +(\d+)- *(\d+): +(\d+) +(\d+) +(\d+) +(\d+) *$#)
	{
	  my ($num0, $num3, $c0, $c1, $c2, $c3)= ($1, $2, $3, $4, $5, $6);
# tim_txcrd_z_vc  0- 3:  0           0           0           0         
# tim_txcrd_z_vc  4- 7:  0           0           0           0         
# tim_txcrd_z_vc  8-11:  0           0           0           0         
# tim_txcrd_z_vc 12-15:  0           0           0           0         
	  # &save_counter ($so, $1, $2, $3);
	  $so->{'tim_txcrd_z_vc'}->[$num0]=   $c0;
	  $so->{'tim_txcrd_z_vc'}->[$num0+1]= $c1;
	  $so->{'tim_txcrd_z_vc'}->[$num0+2]= $c2;
	  $so->{'tim_txcrd_z_vc'}->[$num3]=   $c3;
	  # print 'tim_tx...', main::Dumper ($so->{'tim_txcrd_z_vc'}) if ($num3 == 15);
	}
        else
        {
          print __LINE__, " >>>>> $section [$_]\n";
        }
      }
      elsif ($section eq 'portstats64show')
      {
        if ($_ =~ m#^([\s\w]\w*)\s+(\d+)\s+(.+)#)
	{
          my ($counter, $val, $desc)= ($1, $2, $3);
          if ($counter eq ' ')
	  {
	    $counter= $so->{'counter'} . '_lower';
	  }
	  else
	  {
            $so->{'counter'}= $counter;
	    $counter .= '_upper';
	  }

	  &save_counter ($so, $counter, $val, $desc);
	}
        else
        {
          print __LINE__, " >>>>> $section [$_]\n";
        }
      }
      elsif ($section eq 'switchshow')
      {
        if (/switchName:\s+(.+)/)
        {
          my $switch_name= $1;
          $obj->{'switchName'}= $switch_name;
          $so= $obj->find ('Switch', $switch_name);
          $so->{'_state_'}= 1;
        }
        elsif (/(switchWwn):\s+(.+)/)
        {
          my ($n, $v)= ($1, $2);
          $so->{$n}= $v;
          my $w= $obj->find ('WWN', $v);
          $w->set ('Type' => 'WWNN', 'Note' => 'Switch', 'WWN' => $v);
        }
        elsif (/(switchType|switchState|switchMode|switchRole|switchDomain|switchId|zoning|switchBeacon|blade\d+ Beacon):\s+(.+)/)
        {
          $so->{$1}= $2;
        }

        elsif ($_ eq 'Area Port Media Speed State' # plain switch
            || $_ eq 'Area Port Media Speed State     Proto' # plain switch
              )
        {
          $so->{'_type_'}= 'switch';
        }
        elsif ($_ eq 'Index Port Address Media Speed State     Proto') # switch type 66.1
	{
          $so->{'_type_'}= 'switch2';
	}
        elsif ($_ eq 'Index Slot Port Address Media Speed State     Proto') # director
        {
          $so->{'_type_'}= 'director';
        }
        elsif ($_ eq '=============================='
            || $_ eq '====================================='
            || $_ eq '==============================================' # 66.1
            || $_ eq '===================================================' # director
              )
        {
          $so->{'_state_'}= 2;
        }
        elsif ($so->{'_state_'} == 2)
        {
          my ($Port, $Media, $Speed, $State, $Rest); # all switches
          my ($Area); # plain switches
          my ($Index, $Slot, $Address); # director, however, we set "$Index= $Port" for plain switches too
	  my ($M2); # 66.1

          my ($po); # the Port object used

          if ($so->{'_type_'} eq 'switch')
          {
            ($Area, $Port, $Media, $Speed, $State, $Rest) = split (' ', $_, 6);
            $Index= $Port;  # generally set a port index
            $po= $obj->find ('Port', $Port);
            $po->set ('Area' => $Area);
          }
          elsif ($so->{'_type_'} eq 'switch2')
          {
            ($Index, $Port, $Address, $Media, $Speed, $State, $M2, $Rest) = split (' ', $_, 8);
            $po= $obj->find ('Port', $Port);
            $po->set ('Address' => $Address, 'M2' => $M2);
	    # M2: "FC" on 66.1; TODO: need to check what's up with this.
          }
          elsif ($so->{'_type_'} eq 'director')
          {
            ($Index, $Slot, $Port, $Address, $Media, $Speed, $State, $Rest) = split (' ', $_, 8);

	    # ARGH!!!!  we need port specifier like portshow 2/4 instead of portshow 20
	    my $port_spec= join ('/', $Slot, $Port);
	    $obj->{'PI2PS'}->{$Index}= $port_spec;
	    $obj->{'PS2PI'}->{$port_spec}= $Index;

            $po= $obj->find ('Port', $Index);
            $po->set ('Slot' => $Slot, 'Address' => $Address);
          }
          else
          {
            # TODO: unknown switch type
            print __LINE__, " >>>>> [$_]\n";
          }

          if (defined ($po))
          {
           $po->set ('Media' => $Media, 'Speed' => $Speed, 'State' => $State, 'Port' => $Port, 'Index' => $Index);

           if ($State eq 'Online')
           {
             my ($Type, @Rest)= split (' ', $Rest);

	     if ($Type eq 'FC')
	     { # hmm?  what should 'FC' tell us here?
	       $Type= shift (@Rest);
	     }

             if ($Type eq 'L-Port')
             {
               $po->set ('Type' => $Type, 'L-Port' => join (' ', @Rest));
               push (@{$obj->{'L-Ports'}}, $Index);
             }
             elsif ($Type eq 'G-Port')
             {
               $po->set ('Type' => $Type, 'G-Port' => join (' ', @Rest));
               push (@{$obj->{'G-Ports'}}, $Index);
             }
             elsif ($Type eq 'F-Port' && /F-Port\s+(\d+) NPIV public/)
	     { # e.g. "20    2    4   011400   id    N4   Online           F-Port  4 NPIV public"
               $po->set ('Type' => 'NPIV', 'NPIV_cnt' => $1);
print __LINE__, ' >>> NPIV Port [', $_, "]\n";
               push (@{$obj->{'NPIV-Ports'}}, $Index);
	     }
             elsif ($Type eq 'F-Port' && /F-Port\s+(\d+) N Port \+ (\d+) NPIV public/)
	     { # e.g. "149    2   21   019500   id    N4   Online      FC  F-Port  1 N Port + 2 NPIV public"
               $po->set ('Type' => 'NPIV', 'NPIV_cnt' => $2, 'NPIV_n_cnt' => $1);
print __LINE__, ' >>> NPIV Port [', $_, "]\n";
               push (@{$obj->{'NPIV-Ports'}}, $Index);
	     }
             elsif ($Type eq 'E-Port' || $Type eq 'F-Port')
             {
               my $WWPN= shift (@Rest);
               $po->set ('Type' => $Type, 'WWPN' => $WWPN);
       
               my $wwpn_o= $obj->find ('WWN', $WWPN);
               $wwpn_o->set ('Port_Index' => $Index, 'Type', 'WWPN');

               if ($Type eq 'E-Port')
               { # ISL to another switch
                 push (@{$obj->{'E-Ports'}}, $Index);
                 my $remote_switch= shift (@Rest);
                 my $remote_extra= join (' ', @Rest);
                 $po->set ('remote_switch' => $remote_switch, 'remote_extra' => $remote_extra);
               }
             }
             else
             {
               print __FILE__,':',__LINE__, " unknown port type [$Type] [$_]\n";
             }
           }
           else
           {
             $po->set ('Rest' => $Rest);
             $po->set ('POD_License' => 'No') if ($Rest =~ /No POD License/);
           }
          }
        }
        elsif ($_ eq '') {} # NOP
        else
        {
          print __LINE__, " >>>>> [$_]\n";
        }
      }
      elsif ($section eq 'alishow' || $section eq 'cfgshow')
      {
        if ($_ eq 'Defined configuration:')
        {
          $cfg_obj= $obj->{'Defined_Configuration'};
        }
        elsif ($_ eq 'Effective configuration:')
        {
          $cfg_obj= $obj->{'Effective_Configuration'};
        }
        elsif (/^ (cfg|zone|alias):\s+(.+)/)
        {
          my ($ty, $str)= ($1, $2);
          my ($name, @rest)= split (' ', $str);
## print __LINE__, " >>>> so_line='$so_line'\n";
print __LINE__, " >>>> ty='$ty' name='$name' rest=", join ('|', @rest), "\n" if ($debug_level > 2);

          my $x= $cfg_obj->{$ty}->{$name};
          unless (defined ($x))
          {
            $x= $cfg_obj->{$ty}->{$name}= new Brocade::Config::Item ('name' => $name, 'text' => '');
            $so_line= \$x->{'text'};
            $$so_line .= join (' ', @rest) if (@rest);
## print __LINE__, " >>>> so_line='$so_line'\n";
          }

        }
        elsif (/^\s\s+(\S.*)/)
        {
          my $l= $1;
## print __LINE__, " >>>>>> followup line: '$l'\n";
## print __LINE__, " >>>> so_line='$so_line'\n";
          $$so_line .= ' ' if ($$so_line);
          $$so_line .= $l;
        }
        elsif ($_ eq '') {} # NOP
        else
        {
          print __LINE__, " >>>>> [$_]\n";
        }
      }
      elsif ($section eq 'nsshow')
      {
        if ($_ eq '{' || $_ eq '}' || /^ Type Pid\s+COS\s+PortName\s+NodeName\s+TTL\(sec\)/) {} # NOP
#               [ N    020100;    2,3;10:00:00:00:c9:54:e0:dd;20:00:00:00:c9:54:e0:dd; na]
        elsif (/^\s+(\S+)\s+([a-f\d]+);\s+([\d,]+);([a-f\d:]+);([a-f\d:]+);\s+(.+)/)
        {
          my ($type, $pid, $cos, $wwpn, $wwnn, $ttl)= ($1, $2, $3, $4, $5, $6);
## print __LINE__, ' >> ', $_, "\n";
## print __LINE__, ' << ', "type='$type' pid='$pid' cos='$cos' wwpn='$wwpn' wwnn='$wwnn' ttl='$ttl'\n";
          # type: values such as N, NL
          # pid: hex number, DDAAPP:
          # * DD= Domain (Switch ID)
          # * AA= Area (Switch Port Number)
          # * PP= AL-Port Number
          # cos: eg "2,3" (class-of-service)

          my $wwpn_o= $obj->find ('WWN', $wwpn);
          $wwpn_o->set ('Node' => $wwnn, 'Type' => 'WWPN');
          my $wwnn_o= $obj->find ('WWN', $wwnn);
          $wwnn_o->set ('Type', 'WWNN');

          $node_o= $obj->find ('Node', $wwnn);
          $node_o->set ('type' => $type);
          push (@{$node_o->{'wwpns'}}, $wwpn);
        }
        elsif (/^    (Fabric Port Name):\s+([a-f\d:]+)$/)
        { # that's the WWPN of the switch port
          my ($t, $v)= ($1, $2);
          push (@{$node_o->{$t}}, $v);

          my $wwpn_o= $obj->find ('WWN', $v);
          $wwpn_o->set ('Type', 'WWPN', 'Note' => 'Switch Port');
          push (@{$so->{'WWPNs'}}, $v);
        }
        elsif (/^    (NodeSymb):\s+(.+)$/)
        { # XXX
          # e.g. [    NodeSymb: [41] "QLA2340          FW:v3.03.19 DVR:v7.07.04"]
          # [41] is the number of characters in the string
          my ($t, $v)= ($1, $2);
          push (@{$node_o->{$t}}, $v);
        }
        elsif (/^    (Permanent Port Name):\s+([a-f\d:]+)$/)
        { # XXX
          my ($t, $v)= ($1, $2);
          print __LINE__, " >>>>> nsshow av 't='$t' v='$v' [$_]\n";
          push (@{$node_o->{$t}}, $v);
        }
        elsif (/^    ([\w ]+):\s+(.+)$/)
        { # XXX
          my ($t, $v)= ($1, $2);
          print __LINE__, " >>>>> nsshow av t='$t' v='$v' [$_]\n";
          push (@{$node_o->{$t}}, $v);
        }
        else
        {
          print __LINE__, " >>>>> nsshow [$_]\n";
        }
      }
      elsif ($section eq 'myid')
      {
        print __LINE__, " >>>> {$section} [$_]\n";
        if ($_ =~ /Current Switch:\s+(\S+)$/)
        {
          $obj->{'Current Switch'}= $1;
        }
        elsif ($_ =~ /Session Detail:\s+(\S+)\s+\(([\d\.]+)\)\s+(\S+)\s+(\S+)$/)
        {
          my $Session=
          {
            'Name' => $1,
            'IP' => $2,
            'Mode' => $3,
            'HA_Status' => $4,
          };
          $obj->{'Session'}= $Session;
          # my ($sn, $ip, $mode, $HA_status)= ($1, $2, $3, $4);
          # $obj->set ('Session Name' => $sn, 'Session IP' => $ip, 'Session Mode' => );
        }
        else { goto UK1; }

      # 453 >>>>> {myid} [      Current Switch:  d-sandir2-sw0]
      # 453 >>>>> {myid} [      Session Detail:  d-sandir2-cp0 (131.130.210.112) Standby  Redundant]

      }
      elsif ($section eq 'psshow')
      {
        if ($_ =~ /Power Supply #(\d+) is (.+)/)
	{
	  my ($ps_num, $state)= ($1, $2);
	  if ($state ne 'OK')
	  {
	    push (@{$obj->{'Health'}}, $_);
	  }

	  $ps_obj= { 'num' => $ps_num, 'state' => $state };
	  $obj->{'PowerSupply'}->[$ps_num]= $ps_obj;
	}
	elsif (defined ($ps_obj) && $_ =~ /^\s*(DELTA\s+.+)/)
	{ # no idea what that means: " DELTA DPS1001AB-1EM 23020000603 02   FL2L943C5R0"
	  push (@{$ps_obj->{'extra'}}, $_);
	}
        else { goto UK1; }
      }
      elsif ($section eq 'fanshow')
      {
	if ($_ =~ /^Fan (\d+) is (.+), speed is (\d+) RPM/)
	{
	  my ($fan_num, $state, $RPM)= ($1, $2, $3);
	  if ($state ne 'Ok')
	  {
	    push (@{$obj->{'Health'}}, $_);
	  }

	  my $fan_obj= { 'num' => $fan_num, 'state' => $state, 'RPM' => $RPM };
          $obj->{'Fan'}->[$fan_num]= $fan_obj;
	}
        else { goto UK1; }
      }
      elsif ($section eq 'sensorshow')
      {
	if ($_ =~ /^sensor\s+(\d+):\s+\(([^\)]+)\)\s+is (.+)/)
	{
	  my ($sensor_num, $what, $x_state)= ($1, $2, $3);
	  my ($state, $state_extra)= split (',', $x_state, 2);

	  unless ($state eq 'Ok'
                  || $state eq 'Absent' # this sensor is defined but it does not exist (e.g. blade not built in)
                 )
	  {
	    push (@{$obj->{'Health'}}, $_);
	  }

	  my $sensor_obj= { 'num' => $sensor_num, 'state' => $state, 'what' => $what, 'extra' => $state_extra };
          $obj->{'Sensor'}->[$sensor_num]= $sensor_obj;
	}
        else { goto UK1; }
      }
      elsif ($section eq 'sfpshow')
      {
	if ($_ =~ m#^Port +(\d+): ((..).*)#)
	{
          my ($num, $details, $type)= ($1, $2, $3);

          my $sfp_obj= $obj->find ('SFP' => $num);
	  $sfp_obj->set ('Port' => $num, 'type' => $type, 'details' => $details, 'idx' => $num, 'port_name' => $num);
	}
	elsif ($_ =~ m#^Slot +(\d+)\/Port +(\d+): ((..).*)#)
	{
          my ($slot, $num, $details, $type)= ($1, $2, $3, $4);
	  my $port_index;
          my $port_name= join ('/', $slot, $num);

          if (exists ($obj->{'PS2PI'}))
	  {
	    $port_index= $obj->{'PS2PI'}->{$port_name};
          }
	  else
	  { # TODO: make sure we get the PS2PI hash from the portshow command!
	    print "ATTN: missing data from portshow command\n";
	  }

          my $sfp_obj= $obj->find ('SFP' => $port_index);
	  $sfp_obj->set ('Slot' => $slot, 'Port' => $num, 'type' => $type, 'details' => $details, 'idx' => $port_index, 'port_name' => $port_name);
	}
	elsif ($_ =~ m#([^:]+): *(.+)#)
	{
# ZZZ
	  my ($an, $av)= ($1, $2);
	  $so->{$an}= $av;
	}
	elsif ($_ =~ m#(.+) = +(.+)#)
	{
# ZZZ
	  my ($an, $av)= ($1, $2);
	  $so->{$an}= $av;
	}
	elsif ($_ =~ m# +Alarm *Warn# || $_ =~ m# +low +high +low +high#) {} # NOP
        else { goto UK1; }

=cut


843 >>>>> unmatched {sfpshow} [DD Type:     0x68]
843 >>>>> unmatched {sfpshow} [Enh Options: 0xf0]
843 >>>>> unmatched {sfpshow} [Status/Ctrl: 0x82]
843 >>>>> unmatched {sfpshow} [Alarm flags[0,1] = 0x0, 0x0]
843 >>>>> unmatched {sfpshow} [Warn Flags[0,1] = 0x0, 0x40]
843 >>>>> unmatched {sfpshow} [                                          Alarm                  Warn]
843 >>>>> unmatched {sfpshow} [                                      low        high       low         high]
843 >>>>> unmatched {sfpshow} [Temperature: 32      Centigrade     -15         90         -10         85]
843 >>>>> unmatched {sfpshow} [Current:     5.990   mAmps          2.000       8.500      2.000       8.500]
843 >>>>> unmatched {sfpshow} [Voltage:     3308.3  mVolts         2800.0      3800.0     2970.0      3630.0]
843 >>>>> unmatched {sfpshow} [RX Power:    -30.0   dBm (1.0   uW) 0.0    uW   6550.0 uW  49.0   uW   1100.0 uW]
843 >>>>> unmatched {sfpshow} [TX Power:    -2.5    dBm (557.7 uW) 50.0   uW   800.0  uW  100.0  uW   700.0  uW]

=cut

      }
      else
      {
UK1:
        print __LINE__, " >>>>> unmatched {$section} [$_]\n" unless ($_ eq '');
      }

    }
    else
    {
      print __LINE__, " >>>> [$_]\n";
    }
  }

  $section_count;
}

sub save_counter
{
  my ($so, $counter, $val, $desc)= @_;

  ## print "counter='$counter' val='$val' desc='$desc'\n";

  if (exists ($so->{'_list_'}))
  {
    my $d_l= $so->{'_list_'};
    my $d_d= $so->{'_dict_'};
    my $d_i= @$d_l;

    push (@$d_l, { 'idx' => $d_i, 'counter' => $counter, 'desc' => $desc });
    $d_d->{$counter}= $d_i;
  }

  push (@{$so->{'_d_'}}, $val);
}

=head2 fixup

cross reference configuration data

=cut

sub fixup
{
  my $obj= shift;

  my $eff_cfg= $obj->{'Effective_Configuration'};
  my $def_cfg= $obj->{'Defined_Configuration'};

  my @k= keys %{$eff_cfg->{'cfg'}};  # there should be one entry
  my $cfg_name= shift (@k);
  return undef unless ($cfg_name);

  $obj->{'CFG'}= $cfg_name;

  foreach my $d (keys %{$def_cfg->{'cfg'}})
  {
    my $D= $def_cfg->{'cfg'}->{$d};
    ## main::print_refs (*STDOUT, "D ($d)", $D);

    my $Co= $obj->find ('Config', $d);

    # mark all zones that are members of a configuration
    my $text= $D->{'text'};
    my @members= split (/;\s*/, $text);
## print __LINE__, " cfg='$d' text='$text'\n";
    foreach my $member (@members)
    {
      my $zo= $obj->find ('Zone', $member);
      $zo->{'member_of'}->{$d}++;

      $Co->{'zone'}->{$member}++;
    }
  }

    my $A= $def_cfg->{'alias'};
    my @A= sort keys %$A;
    foreach my $alias (@A)
    {
## print __LINE__, " alias='$alias'\n";
      my $a= $A->{$alias};
      my $wwn= $a->{'text'};

      # TODO: check if wwn is really a WWN;
      # NOTE: a WWN for an alias can be a WWNN or WWPN
      $wwn= $1 if ($wwn =~ /^H{([0-9a-fA-F:]+)}$/);
      $wwn=~ tr/A-F/a-f/;

      my $wo= $obj->find ('WWN', $wwn);
      $wo->{'Alias'}->{$alias}++;

      my $ao= $obj->find ('Alias', $alias);
      $ao->set ('WWN', $wwn);

## print __LINE__, " wo='$wo' ", main::Dumper ($wo), "\n";
      if (exists ($wo->{'Port_Index'}))
      {
        my $port_index= $wo->{'Port_Index'};
## print __LINE__, " port_index='$port_index' alias='$alias'\n";
        my $po= $obj->find ('Port', $port_index);
        $po->{'Alias'}->{$alias}++;
        # $po->{'Alias'}->{$alias} += __LINE__;
      }
    }

    my $Z= $def_cfg->{'zone'};
    my @Z= sort keys %$Z;
    foreach my $zone (@Z)
    {
      my $zo= $obj->find ('Zone', $zone);

      my $z= $Z->{$zone};
      my $members= $z->{'text'};
      my @members= split (/;\s*/, $members);
      foreach my $member (@members)
      {
        my $ao= $obj->find ('Alias', $member);
        $ao->{'Zone'}->{$zone}++;

        $zo->{'Alias'}->{$member}++;
      }
    }

  undef;
}

# ======================================================================
# policy: port names should reflect the WWN alias of the connected HBA
sub check_port_names
{
  my $config= shift;

  my @ACTIONS= ();
  my $Ports= $config->{'Port'};
  ## print __LINE__, " Ports=", main::Dumper ($Ports), "\n";

print __FILE__, ' ', __LINE__, " >> check_port_names()\n";
  my %cnt;
  foreach my $port_index (sort { $a <=> $b } keys %$Ports)
  {
    my $po= $Ports->{$port_index};

    my ($state, $name, $aliases, $wwn, $wwpn, $pod, $Index, $Slot, $Port)=
       map { $po->{$_} } qw(State name Alias WWN WWPN POD_License Index Slot Port);
    # Note: WWPN will be set usually, where comes WWN from?

    my @aliases= (defined ($aliases)) ? sort keys %$aliases : ();

    if ($state eq 'No_Module')
    {
      $cnt{($pod eq 'No') ? 'No_POD_License' : 'No_Module'}++;
      next;
    }

# print __FILE__, ' ', __LINE__, " >>> ", join (' ', %$po), "\n";
# print __LINE__, " >>>> aliases: ", join (' ', @aliases), "\n";
## print __LINE__, " Port $port_index", main::Dumper ($po), "\n";

    if (!@aliases && ($wwn || $wwpn))
    {
      print "## ATTN: port $port_index, name='$name', no alias for (wwn=[$wwn], wwpn=[$wwpn])\n";
      # Note: there might be different cases if a name is defined or not
    }

    if (defined ($name))
    {
      if (@aliases)
      {
        if (!exists ($aliases->{$name}))
        {
          print "## ATTN: port $port_index name '$name' not in aliases: ", join (' ', @aliases), "\n";
          $cnt{'No_Alias'}++;
        }
      }
    }
    elsif (!defined ($name) && $state eq 'Online' && @aliases)
    {
      my $alias= shift (@aliases);
      my $port_specifier= ($Slot) ? "$Slot/$Port" : $Port;

# print __FILE__, ' ', __LINE__, " missing port name: ", main::Dumper ($po), "\n";

      my $action= "portname $port_specifier '$alias'";
      push (@ACTIONS, $action);
      print $action, "\n";
      $cnt{'Name_Missing'}++;

      print "alternative names: ", join (' ', @aliases), "\n" if (@aliases);
    }

  }

  print "### ACTIONS:\n";
  foreach my $action (@ACTIONS)
  {
    print $action, "\n";
  }

  \%cnt;
}

# ======================================================================
sub zone_as_html
{
  my $config= shift;
  my $fnm_out= shift;
  my $title= shift;

  my $ts_f= scalar localtime ($config->{'file_date'});
  my $ts_h= scalar localtime (time ());
  my $zf= $config->{'zone_file'};

  open (FO, ">$fnm_out") or die;
  print FO <<EOX;
<title>$title</title>

<h1>$title</h1>

<table>
  <tr>
    <td>zone file:</td>
    <td><a href="$zf">$zf</a></td>
  </tr>
  <tr><td>configuration retrieved:</td><td>$ts_f</td></tr>
  <tr><td>configuration processed:</td><td>$ts_h</td></tr>
</table>

EOX

  $config->print_WWN_information (*FO);
  $config->print_cfg_information (*FO);
  $config->print_zoning_information (*FO);
  $config->print_alias_information (*FO);
  
  close (FO);
}

sub print_port_information_switch
{
  my $config= shift;
  local *FO= shift;

  print FO <<EOX;
<h2>Ports</h2>
<table border=1>
<tr>
  <th>Port</th>
  <th>Speed</th>
  <th>State</th>
  <th>Type</th>
  <th>Name</th>
  <th>WWPN</th>
</tr>
EOX

  my $Ports= $config->{'Port'};
  foreach my $port_index (sort { $a <=> $b } keys %$Ports)
  {
    my $po= $Ports->{$port_index};

    my ($state, $speed, $type)= map { $po->{$_} || '&nbsp;' } qw(State Speed Type);
    # next if ($state eq 'No_Module');
    my ($name, $wwn)= map { my $x; ($x= $po->{$_}) ? "<a href=\"#$x\">$x</a>" : '&nbsp;' } qw(name WWPN);

    print FO <<EOX;
<tr>
  <td>$port_index</td>
  <td>$speed</td>
  <td>$state</td>
  <td>$type</td>
  <td>$name</td>
  <td>$wwn</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX
}

sub print_port_information_blade # director blade!
{
  my $config= shift;
  local *FO= shift;

  print FO <<EOX;
<h2>Ports</h2>
<table border=1>
<tr>
  <th>Index</th>
  <th>Slot</th>
  <th>Port</th>
  <th>Speed</th>
  <th>State</th>
  <th>Type</th>
  <th>Name</th>
  <th>WWPN</th>
</tr>
EOX

  my $Ports= $config->{'Port'};
  foreach my $port_index (sort { $a <=> $b } keys %$Ports)
  {
    my $po= $Ports->{$port_index};

    my ($slot, $port, $state, $speed, $type)= map { defined ($po->{$_}) ? $po->{$_} : '&nbsp;' } qw(Slot Port State Speed Type);
    # next if ($state eq 'No_Module');
    my ($name, $wwn)= map { my $x; ($x= $po->{$_}) ? "<a href=\"#$x\">$x</a>" : '&nbsp;' } qw(name WWPN);

    print FO <<EOX;
<tr>
  <td>$port_index</td>
  <td>$slot</td>
  <td>$port</td>
  <td>$speed</td>
  <td>$state</td>
  <td>$type</td>
  <td>$name</td>
  <td>$wwn</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX
}

sub ports_as_csv
{
  my $config= shift;
  my $fnm_out= shift;

  return undef unless ($config);

  my ($title, $CFG)= map { $config->{$_}; } qw(switchName CFG);
  open (FO, ">$fnm_out") or die;

  print FO join ($CSV_SEPARATOR, qw(switch CFG slot port_num port_index speed state type port_name wwpn)), "\n";
  # NOTE: slot might be something like 9, port_num 26 while port_index would be 234
  # TODO: check if this naming convention is consistent with other places

  my $Ports= $config->{'Port'};
  foreach my $port_index (sort { $a <=> $b } keys %$Ports)
  {
    my $po= $Ports->{$port_index};

    my ($slot, $port, $state, $speed, $type, $name, $wwpn)= map { defined ($po->{$_}) ? $po->{$_} : '' } qw(Slot Port State Speed Type name WWPN);

    print FO join ($CSV_SEPARATOR, $title, $CFG,
$slot, $port, $port_index, $speed, $state, $type, $name, $wwpn),
 "\n";
  }
  close (FO);
}

sub portlayout_as_html
{
  my $config= shift;
  my $fnm_out= shift;

  return undef unless ($config);

  my ($ts, $title, $CFG, $zf, $dom)= map { $config->{$_}; } qw(file_date switchName CFG zone_file);
  $CFG= 'NONE' unless ($CFG);
  my $x= $config->{'Switch'}->{$title};
  my ($ty, $wwn, $dom)= map { $x->{$_}; } qw(switchType switchWwn switchDomain);
  my $ip= $config->{'Session'}->{'IP'};

  my $ts_f= scalar localtime ($ts);
  my $ts_h= scalar localtime (time ());
  my $CFG_html= "zone-$CFG.html";

  open (FO, ">$fnm_out") or die;
  print FO <<EOX;
<HEAD>
<STYLE TYPE="text/css">
     BR {page-break-after: always}
</STYLE>
<title>$title</title>
</HEAD>

<h1>$title</h1>

<table border=0>
<tr><td>configuration retrieved:</td><td>$ts_f</td></tr>
<tr><td>configuration processed:</td><td>$ts_h</td></tr>
<tr><td colspan=3>&nbsp;</tr>
<tr><td>Switch Type:</td><td>$ty</td></tr>
<tr><td>Switch WWN:</td><td>$wwn</td></tr>
<tr><td>Switch Domain:</td><td>$dom</td></tr>
<tr><td>IP-Address:</td><td>$ip</td></tr>
<tr><td>Config</td><td><a href="$CFG_html">$CFG</a></td></tr>
<tr><td>zone_file</td><td><a href="$zf">$zf</a></td></tr>
</table>
EOX

  if (exists ($PORTS_LAYOUT->{$ty}))
  {
    my $L= $PORTS_LAYOUT->{$ty};

    if ($L->{'layout_1'} eq 'as blade')
    {
      $config->print_port_information_blade (*FO, $L);
      # $config->print_port_information_blade (*FO);
    }
    else
    {
      $config->print_port_information_layout (*FO, $L);
      $config->print_port_information_switch (*FO);
    }
  }
  else
  {
    $config->print_port_information_switch (*FO);
  }
  
  close (FO);
}

sub print_port_information_layout
{
  my $config= shift;
  local *FO= shift;
  my $layout= shift;

  my ($ts, $title)= map { $config->{$_}; } qw(file_date switchName);
  my $x= $config->{'Switch'}->{$title};
  my ($ty, $wwn)= map { $x->{$_}; } qw(switchType switchWwn);

  print FO <<EOX;
<h2>Ports Brocade $title (switchType $ty)</h2>
EOX

  my $n_groups= $layout->{'groups'};
  my $n_columns= $layout->{'columns'};
  my $n_ports_per_group= $n_groups * $n_columns;
  my $ports_layout= $layout->{'layout'};

  my $Ports= $config->{'Port'};
  for (my $group=0; $group < $n_groups; $group++)
  {
    print FO <<EOX;

<table border=1 width="100%">
<tr>
  <th colspan=7>Port Group $group</th>
</tr>
<tr>
  <th colspan=3>lower row</th>
  <th width="3%">&nbsp;</th>
  <th colspan=3>upper row</th>
</tr>
<tr>
  <th width="30%">Name</th>
  <th width="10%">State</th>
  <th width="5%">Port</th>
  <th width="3%">&nbsp;</th>
  <th width="5%">Port</th>
  <th width="10%">State</th>
  <th width="30%">Name</th>
</tr>
EOX

   for (my $column= 0; $column < $n_columns; $column++)
   {
    # port on the right (== upper) side
    my $pn_r= $group*$n_ports_per_group + $ports_layout->[0]->[$column];
    my $po_r= $Ports->{$pn_r};
    my ($state_r, $speed_r, $type_r, $lic_r)= map { $po_r->{$_} || '&nbsp;' } qw(State Speed Type POD_License);
    my ($name_r, $wwn_r)= map { my $x; ($x= $po_r->{$_}) ? "<a href=\"#$x\">$x</a>" : '&nbsp;' } qw(name WWPN);
    $state_r = 'No_License' if ($lic_r eq 'No');

    # port on the left (== lower) side
    my $pn_l= $group*$n_ports_per_group + $ports_layout->[1]->[$column];
    my $po_l= $Ports->{$pn_l};
    my ($state_l, $speed_l, $type_l, $lic_l)= map { $po_l->{$_} || '&nbsp;' } qw(State Speed Type POD_License);
    my ($name_l, $wwn_l)= map { my $x; ($x= $po_l->{$_}) ? "<a href=\"#$x\">$x</a>" : '&nbsp;' } qw(name WWPN);
    $state_l = 'No_License' if ($lic_l eq 'No');

    print FO <<EOX;
<tr>
  <td align=right>$name_l</td>
  <td>$state_l</td>
  <td>$pn_l</td>
  <td>&nbsp;</td>
  <td>$pn_r</td>
  <td>$state_r</td>
  <td>$name_r</td>
</tr>
EOX

    if (($column % 4) == 3)
    {
      print FO "<tr><td colspan=7>&nbsp</td></tr>\n";
    }

   }

  print FO <<EOX;
</table>
<br>

EOX
  }
}

sub print_WWN_information
{
  my $config= shift;
  local *FO= shift;

  print FO <<EOX;
<h2>WWNs</h2>
List of WWNs: WWPNs and WWNNs
<table border=1>
<tr>
  <th>WWN</th>
  <th>Type</th>
  <th>Alias(es)</th>
  <th>WWNN</th>
  <th>WWPNs</th>
  <th>Notes</th>
</tr>
EOX

  my $WWNs= $config->{'WWN'};
  foreach my $wwn (sort keys %$WWNs)
  {
    my $wo= $WWNs->{$wwn};
    my $ty= $wo->{'Type'} || '&nbsp;';
    my $note= $wo->{'Note'} || '&nbsp;';

    my $node= $wo->{'Node'};
    if ($node)
    {
      $node= "<a href=\"#$node\">$node</a>";
    }
    else { $node= '&nbsp;'; }

    my $wwpns;
    if ($ty eq 'WWNN')
    {
      my $node_o= $config->find ('Node', $wwn);
      $wwpns= join (', ', map { "<a href=\"#$_\">$_</a>"; } @{$node_o->{'wwpns'}});
    }
    $wwpns= '&nbsp;' unless ($wwpns);

    my $aliases= join (' | ', map { "<a href=\"#$_\">$_</a>" } sort keys %{$wo->{'Alias'}});
    $aliases= '&nbsp;' unless ($aliases);

    print FO <<EOX;
<tr>
  <td><a name="$wwn">$wwn</a></td>
  <td>$ty</td>
  <td>$aliases</td>
  <td>$node</td>
  <td>$wwpns</td>
  <td>$note</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX
}

sub print_cfg_information
{
  my $config= shift;
  local *FO= shift;

  # print configuration names and their zones
  print FO <<EOX;
<h2>Configurations</h2>
<table border=1>
<tr>
  <th>Config</th>
  <th>is active</th>
  <th>Zones</th>
</tr>
EOX

  my $active_config= $config->{'CFG'};
  my $Configs= $config->{'Config'};
  foreach my $cfg (sort keys %$Configs)
  {
    my $is_active= ($cfg eq $active_config) ? 'ACTIVE' : '&nbsp;';
    my $zones= join (' ', map { "<a href=\"#$_\">$_</a><br>"; } sort keys %{$Configs->{$cfg}->{'zone'}});

    print FO <<EOX;
<tr>
  <td><a name="$cfg">$cfg</a></td>
  <td>$is_active</td>
  <td>$zones</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX
}

sub print_zoning_information
{
  my $config= shift;
  local *FO= shift;

  # print zoning configuration
  print FO <<EOX;
<h2>Zones</h2>
<table border=1>
<tr>
  <th>Zone</th>
  <th>Config</th>
  <th>Aliases</th>
</tr>
EOX

  my %dangling_zones= ();
  my $Zones= $config->{'Zone'};
  foreach my $zone (sort keys %$Zones)
  {
    my $zo= $Zones->{$zone};

    # which configurations does this zone belong to?
    my $cfgs= $zo->{'member_of'};
    my $configs;
    if (defined ($cfgs))
    {
      $configs= join (' ', map { "<a href=\"#$_\">$_</a>"; } sort keys %$cfgs);
    }
    else
    {
      $configs= '&nbsp;';
      push (@{$dangling_zones{$zone}}, 'nocfg');
    }

    # which members does this zone have?
    my $members;
    if (exists ($zo->{'Alias'}))
    {
      $members= join (' ', map { "<a href=\"#$_\">$_</a>"; } sort keys %{$zo->{'Alias'}});
    }
    else
    {
      push (@{$dangling_zones{$zone}}, 'nomember');
    }

    print FO <<EOX;
<tr>
  <td><a name="$zone">$zone</a></td>
  <td>$configs</td>
  <td>$members</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX

  if (keys %dangling_zones)
  {
    print FO <<EOX;
<h3>Dangling Zones</h3>
<table border=1>
<tr>
  <th>Zone</th>
  <th>Reason</th>
</tr>
EOX

    foreach my $zone (sort keys %dangling_zones)
    {
      my $reason= join (' ', @{$dangling_zones{$zone}});
      print FO <<EOX;
<tr>
  <td>$zone</td>
  <td>$reason</td>
</tr>
EOX
    }

    print FO <<EOX;
</table>
EOX
  }
}

sub print_alias_information
{
  my $config= shift;
  local *FO= shift;

  # print alias information
  print FO <<EOX;
<h2>Aliases</h2>
<table border=1>
<tr>
  <th>Alias</th>
  <th>WWN</th>
  <th>Type</th>
  <th>Zones</th>
</tr>
EOX

  my %dangling_aliases= ();
  my $Aliases= $config->{'Alias'};
  foreach my $alias (sort keys %$Aliases)
  {
    my $ao= $Aliases->{$alias};
    my $wwn= $ao->{'WWN'};

    my $zones;
    my $zp= $ao->{'Zone'};
    if (defined ($zp))
    {
      $zones= join (' ', map { "<a href=\"#$_\">$_</a><br>" } sort keys %$zp);
    }
    else
    {
      $zones= '&nbsp;';
      push (@{$dangling_aliases{$alias}}, 'nozone'); # this alias is not member of any zone
    }

    my $wwn_o= $config->find ('WWN', $wwn);
## print_refs (*STDOUT, 'wwn_o', $wwn_o);
    my $ty= $wwn_o->{'Type'} || '&nbsp;';

    print FO <<EOX;
<tr>
  <td><a name="$alias">$alias</a></td>
  <td><a href="#$wwn">$wwn</a></td>
  <td>$ty</td>
  <td>$zones</td>
</tr>
EOX
  }

  print FO <<EOX;
</table>
EOX

  if (keys %dangling_aliases)
  {
    print FO <<EOX;
<h3>Dangling Aliases</h3>

<p>These aliases are not member of any zone.  However, they may
have been defined for other reasons</p>

<table border=1>
<tr>
  <th>Alias</th>
  <th>Reason</th>
</tr>
EOX

    foreach my $alias (sort keys %dangling_aliases)
    {
      my $reason= join (' ', @{$dangling_aliases{$alias}});
      print FO <<EOX;
<tr>
  <td><a href="#$alias">$alias</a></td>
  <td>$reason</td>
</tr>
EOX
    }

    print FO <<EOX;
</table>
EOX
  }
}

# this is a stripped down version of print_alias_information
sub print_alias_information_csv
{
  my $config= shift;

  my $cfg_name= $config->get_cfg_name ();
  my $alias_file= $config->{'alias_csv'}= $cfg_name .'-alias.csv';
  open (FO, ">$alias_file") or return undef;

  local *FO= shift;
  # print alias information
  print FO join ($CSV_SEPARATOR, qw(fabric alias wwn zones)), "\n";

  my $Aliases= $config->{'Alias'};
  foreach my $alias (sort keys %$Aliases)
  {
    my $ao= $Aliases->{$alias};
    my $wwn= $ao->{'WWN'};

    my $zones;
    my $zp= $ao->{'Zone'};
    if (defined ($zp))
    {
      $zones= join ($CSV_FIELD_SEPARATOR, sort keys %$zp);
    }
    else
    {
      $zones= '';
    }

    my $wwn_o= $config->find ('WWN', $wwn);
## print_refs (*STDOUT, 'wwn_o', $wwn_o);
    my $ty= $wwn_o->{'Type'} || '&nbsp;';

    print FO join ($CSV_SEPARATOR, $cfg_name, $alias, $wwn, $zones), "\n";
  }

  $alias_file;
}

sub get_cfg_name
{
  my $obj= shift;

  my $cfg_name;
  return $cfg_name if (defined ($cfg_name= $obj->{'CFG'}));

  my $eff_cfg= $obj->{'Effective_Configuration'};
  my @k= keys %{$eff_cfg->{'cfg'}};  # there should be one entry
  my $cfg_name= shift (@k);
  return undef unless ($cfg_name);

  $obj->{'CFG'}= $cfg_name;
}

=cut

=head2 $obj->get_effective_zones ([format])

Write effective zones in policy-stanza format.

=cut

sub get_effective_zones
{
  my $obj= shift;
  my $fmt= shift || 'policy'; # TODO: allow different formats, e.g. csv

  my $eff_cfg= $obj->{'Effective_Configuration'};
  my $def_cfg= $obj->{'Defined_Configuration'};

  my $cfg_name= $obj->get_cfg_name ();
  return undef unless (defined ($cfg_name));

  my $zone_file;
  if ($fmt eq 'csv')
  {
    $zone_file= $obj->{'zone_csv'}= $cfg_name .'-zones.csv';
  }
  else
  {
    $zone_file= $obj->{'zone_file'}= $cfg_name .'.zones';
  }

  open (FO, ">$zone_file") or die;
  print "writing zones to '$zone_file'\n";

  my $now= time ();
  my $now_s= localtime ($now);

  if ($fmt eq 'csv')
  {
    print FO join ($CSV_SEPARATOR, qw(fabric zone wwns aliases)), "\n";
  }
  else
  {
    print FO <<EOX;
timestamp:
   class = cfg
   type = timestamp
   fabric = $cfg_name
   timestamp = $now
   date = $now_s
EOX
  }

  my $zones= $eff_cfg->{'zone'};
  my $def_zones= $def_cfg->{'zone'};
  foreach my $zone (sort keys %$zones)
  {
    my $zp= $zones->{$zone};
    my ($name, $text)= map { $zp->{$_} } qw(name text);
    my @m= split (' ', $text);
    my @mn= split (/; */, $def_zones->{$zone}->{'text'});

    if ($fmt eq 'csv')
    {
      print FO join ($CSV_SEPARATOR, $cfg_name, $name, join ($CSV_FIELD_SEPARATOR, @m), join ($CSV_FIELD_SEPARATOR, @mn)), "\n";
    }
    else
    {
      print FO <<EOX;
$name:
   class = cfg
   type = zone
   fabric = $cfg_name
   name = $name
EOX

      foreach my $m (@m)
      { # TODO: check if this is a WWN or a port number
        $m=~ tr/A-Z/a-z/;
        print FO "   wwn = $m\n";
      }
    }
  }

  close (FO);

  $zone_file;
}

1;

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

Gerhard Gonter E<lt>ggonter@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE
                                                                                
Copyright (C) 2006..2010 by Gerhard Gonter
                                                                                
This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=over

