#
# FILE AIX/NIM/Config.pm
#
# NIM configuration data processing
#
# $Id: Config.pm,v 1.20 2012/06/10 12:03:13 gonter Exp $
#

=pod

=head1 NAME

AIX::NIM::Config - Handle AIX NIM Configuration Data

=head1 SYNOPSIS

  use AIX::NIM::Config;
  my $cnf= new AIX::NIM::Config;  # prepare NIM config object
  $cnf->get_config ();            # actually read current configuration
                                  # from lsnim -l output

  $cnf->get_config ($filename);   # read configuration from file

  my @names= $cnf->get_object_names ();    # return names of all NIM objects
  my @nim_objects= $cnf->get_objects ();   # return all NIM objects
  my $master= $cnf->get_object ('master'); # returns the named NIM object
  # returned NIM object are members of the class AIX::NIM::Object

  my @objects= $cnf->select_objects ('type' => $type, 'class' => $class, ...);
  # return list of objects that match this attribut/value list

  $cnf->print_html (*FILE, $hostname);  # print NIM server configuration to
                                        # *FILE and use hostname in the title

=head1 REMARKS

This module may be used to read configuration files which are not
related to NIM on AIX.  The file format is a simple text file
containing stanzas which describe configuration entities.  Such
stanzas might be useful for many purposes, therefore, the author
is using it in other context as well.  This module is intended to
be portable for any platform where Perl runs.  Check the "SEE ALSO"
section for a link to more applications that use this module.

=head1 DESCRIPTION

=cut

use strict;

use AIX::NIM::Object;

package AIX::NIM::Config;

my $VERSION= '0.07';

my $LSNIM= '/usr/sbin/lsnim';

my @C_machines= qw(alternate_master dataless diskless master standalone);
my @C_networks= qw(atm ent fddi generic tok);
my @C_resources= qw(adapter_def boot bosinst_data dump exclude_files
       fb_script fix_bundle home image_data installp_bundle lpp_source
       mksysb nim_script paging resolv_conf root savevg script
       shared_home spot tmp vg_data);

my @ORDER=
qw(master alternate_master standalone dataless diskless
   mksysb exclude_files
   lpp_source installp_bundle
   generic ent atm fddi tok mac_group
   resolv_conf
   boot bosinst_data
   image_data
   nim_script
   script spot
  );

my $ORDER= 0;
my %ORDER=  map { $_=>$ORDER++ } @ORDER;
push_order (@C_machines);
push_order (@C_networks);
push_order (@C_resources);

sub push_order
{
  foreach (@_)
  { unless (exists ($ORDER{$_})) { push (@ORDER, $_); $ORDER{$_}= $ORDER++; }
  }
}
# print "\@ORDER: ", join (' ', @ORDER), "\n";
# print "\%ORDER: ", join (' ', %ORDER), "\n";

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj=
  {
    'objects' => {},
    'classes' => {},
    'types' => {},
  };
  bless $obj, $class;

  my $par;
  foreach $par (keys %par)
  {
    my $v= $par{$par};
       if ($par eq 'object') { $obj->get_object_config ($v); }
    elsif ($par eq 'type')   { $obj->get_type_config   ($v); }
    elsif ($par eq 'class')  { $obj->get_class_config  ($v); }
    elsif ($par eq 'config') { $obj->get_config        ($v); }
    else { $obj->{$par}= $par{$par}; }
  }

  $obj;
}

=pod

=head2 $cnf->get_object_config([, $names]);

=head2 $cnf->get_type_config([, $names]);

=head2 $cnf->get_class_config([, $names]);

get NIM object, type or class configurations by calling get_lsnim

=head2 $cnf->get_lsnim($flag[, $names]);

get NIM configuration by calling lsnim $flag, optionally with a
list of item names.

=cut

sub get_object_config { shift->get_lsnim ('-l',  @_); }
sub get_type_config   { shift->get_lsnim ('-lt', @_); }
sub get_class_config  { shift->get_lsnim ('-lc', @_); }

sub get_lsnim
{
  my $obj= shift;
  my $flag= shift;

  my @names= ();
  my $object_name;
  while (defined ($object_name= shift (@_)))
  {
    if (ref ($object_name) eq '')
    {
      push (@names, $object_name);
    }
    elsif (ref ($object_name) eq 'ARRAY')
    {
      push (@names, @$object_name);
    }
    elsif (ref ($object_name) eq 'HASH')
    {
      push (@names, keys %$object_name);
    }
  }

  foreach $object_name (@names)
  {
    my $cmd= "$LSNIM '$flag' '$object_name'|";
    $obj->get_config ($cmd);
  }
}

=pod

=head2 $cnf->get_config ($filename)

get_config usually parses the output of lsnim which produces output
in a stanza format.  This feature can also be used to read configuration
data from a stanza file.

=cut

sub get_config
{
  my $obj= shift;
  my $input= shift;

  my $cmd= "$LSNIM -l";
  $input= "$cmd|" unless ($input);
## print "AIX::NIM::Config::get_config input=[$input]\n";

  open (FI, $input) || die "cant read '$input'";
  my $vrb= $obj->{'verbose'};
  print "parsing nim configuration data '$input'\n" if ($vrb);
  $obj->{'_source_'}= $input;

  my @l= ();
  while (<FI>)
  {
    chop;
    print ">>> [$_]\n" if ($vrb > 3);
    push (@l, $_);
  }
  close (FI);

  $obj->analyze_config (@l);
}

=pod

=head2 $n->analyze_config (@lines)

The array @lines contains the text of one or more NIM configuration
stanzas.  This method is usually called by get_config to actually
process those stanza lines that were retrieved either from a file
or pipe.

=cut

sub analyze_config
{
  my $obj= shift;
  my @l= @_;

  my $nim_object;
  my $object_name;

  my $l;
  while (defined ($l= shift @l))
  {
    ## print __LINE__, " >>> $l\n";

    if ($l =~ /^([\w\d\-_]+):$/
	### && $l[0] =~ /^\s+class\s+=/  # begin of stanza
       )
    { # start object description stanza
      $object_name= $1;
      $obj->{'objects'}->{$object_name}= $nim_object= new AIX::NIM::Object ($object_name);
      ## push (@o, $nim_object);
      ## print __FILE__, ' ', __LINE__, " >>>> $object_name $nim_object\n";
    }
    elsif ($l =~ /^\s+([\w\d_]+)\s+=\s*(.*)/)
    {
      my ($an, $av)= ($1, $2);
      $av=~ s/\s*$//;
      $nim_object->av ($an, $av);

      $obj->{'classes'}->{$av}++ if ($an eq 'class');
      $obj->{'types'}->{$av}++ if ($an eq 'type');
    }
    else
    {
      print "ATTN: unknown line format in object $object_name: '$l'\n";
    }
  }
}

=pod

=head2 $cnf->add_object ($nim_object)

Add specified NIM object to NIM configuration

=cut

sub add_object
{
  my $cnf= shift;
  my $nim_object= shift;

  my $object_name= $nim_object->av ('_name_');
  $cnf->{'objects'}->{$object_name}= $nim_object;
}

=pod

=head2 @names= $n->get_object_names ();

=head2 $names= $n->get_object_names ();

Retrieves the names of all objects in the given configuration object.
In array context, the result is returned as an array, otherwise an
array reference is returned.

=cut

sub get_object_names
{
  my $obj= shift;

  my $NO= $obj->{'objects'};
  my @NO= keys %$NO;

  (wantarray) ? @NO : \@NO;
}

=pod

=head2 $n->get_objects ();

Retrieves all objects (not their names, see above) in the given
configuration object.  In array context, the result is returned as
an array, otherwise an array reference is returned.

=cut

sub get_objects
{
  my $obj= shift;

  my $NO= $obj->{'objects'};
  my @NO= values %$NO;

  (wantarray) ? @NO : \@NO;
}

=pod

=head2 $object= $n->get_object ($name)

Retrieve a particular NIM object.

=cut

sub get_object
{
  my $obj= shift;
  my $name= shift or return undef;

  $obj->{'objects'}->{$name};
}

=pod

=head2 $cnf->select_objects ([name => value]+);

Find all objects that match a given list of attribute/value pairs.

For example, to select all standalone machines:

  my $standalone= $n->select_objects ('class' => 'machines', 'type' => 'standalone');

NOTE/BUG: only matches first attribute!

=cut

sub select_objects
{
  my $cnf= shift;
  my %av= @_;      # attribute-value pairs

  my @res;

  my @o= $cnf->get_objects ();
  my ($o, $a);
  foreach $o (@o)
  {
    my $match= 1;
    foreach $a (sort keys %av)
    {
      my $av= $o->av ($a);
      ## print "a='$a' av='$av'\n";

      if (ref ($av) eq '')
      {
	next if ($av{$a} eq $av);
      }
      $match= 0;
    }

    if ($match)
    {
      ## print "match: $o", &main::print_refs (*STDOUT, 'matched_object', $o);
      push (@res, $o);
    }
  }

  (wantarray) ? @res : \@res;
}

=pod

=head2 $n->order_objects ()

Order the objects in some "meaningful" way, that is, we want first
the master, then all the other machines, etc.

Depending on the context, this method either returns an array or a
array reference of object names.

=cut

sub order_objects
{
  my $obj= shift;

  my $NO= $obj->{'objects'};
  my @NO= keys %$NO;
  # print "NO='$NO' cnt='", scalar @NO, "'\n";

  my @oorder= ();
  my $on;
  foreach $on (@NO)
  {
    my $o= $NO->{$on};
    my $ot= $o->{'type'};
    my $oo= $ORDER{$ot};

    # print __FILE__, ' ', __LINE__, " adding $on as $ot to group $oo\n";
    push (@{$oorder[$oo]}, $on);
  }

  # print __LINE__, " ", join (' ', @oorder), "\n";
  my @order= ();
  my $i;
  for ($i= 0; $i <= $#oorder; $i++)
  {
    my $x= $oorder[$i];
    # print "x='$x'\n";
    push (@order, sort @$x) if (defined ($x));
  }

  # print __LINE__, " ", join (' ', @order), "\n";
  (wantarray) ? @order : \@order;
}

=pod

=head2 $n->print_html (*OUTPUT, $hostname)

Prints a cross-referenced HTML stream describing the current configuration object.

=cut

# TODO: this method should possibly not produce the entire HTML structure,
# instead, it should only produce those parts that can be embedded within another
# HTML page.

sub print_html
{
  my $obj= shift;
  local *F= shift;
  my $hostname= shift;

  my $O= $obj->{'objects'};
  my @ON= $obj->order_objects;
  my $on;

  my $verbose= $obj->{'verbose'};

  my $lt= scalar localtime (time ());

  print F <<EOX;
<html>
<head>
<title>NIM configuration on server $hostname</h1>
</head>
<body>
<h1>NIM configuration on server $hostname</h1>
<p>generated: $lt</p>

<h2>Table of Contents</h2>
<ul>
<li><a href="#nim_objects">NIM Objects</a></li>
<li>Objects by type
  <ul>
EOX

  my $last_type= undef;
  foreach $on (@ON)
  {
    my $o= $O->{$on};
    my ($oc, $ot, $avpl)= map {$o->{$_}} qw(class type _);

    if ($ot ne $last_type)
    {
      $last_type= $ot;
      print F <<EOX;
  <li><a href="#ot_$ot">objects type $ot</a></li>
EOX
    }
  }

  print F <<EOX;
   </ul>
   </li>
<li>Statistics
  <ul>
    <li><a href="#host_names">host name table</a></li>
    <li><a href="#an_stats">attribute name statistics</a></li>
  </ul>
</ul>

<h2><a name="nim_objects">NIM objects</a></h2>
<table border=1 width="100%">
<tr>
  <th>object</th>
  <th>class</th>
  <th>type</th>
</tr>
EOX

  foreach $on (@ON)
  {
    my $o= $O->{$on};
    my ($oc, $ot)= map {$o->{$_}} qw(class type);

    print F <<EOX;
<tr>
  <td><a href="#$on">$on</a></td>
  <td>$oc</td>
  <td>$ot</td>
</tr>
EOX
  }

  print F <<EOX;
</table>
EOX

  my %FILE_PRINTED= (); # object name where file was already printed
  my %CNT_AN= ();       # count attribute names by object type
  my %HOSTS= ();
  my %NETS= ();
  $last_type= undef;
  foreach $on (@ON)
  {
    my $o= $O->{$on};
    my ($oc, $ot, $avpl)= map {$o->{$_}} qw(class type _);

    if ($ot ne $last_type)
    {
      $last_type= $ot;
      print F <<EOX;
<h2><a name="ot_$ot">objects type $ot</a></h2>
EOX
    }

    # print one object's attribute name and value pairs
    print F <<EOX;
<h3>object <a name="$on">$on</a></h3>
<table border=1>
<tr>
  <th>attribute</th>
  <th>value</th>
</tr>
EOX

    my @copy_files= ();
    my $avp;
    foreach $avp (@$avpl)
    {
      my ($an, $av)= @$avp;
      my $av_html= $av;

      $CNT_AN{$an}->{$ot}++;

      if ($an eq 'serves' || $an eq 'server' || $an =~ /^member\d+/)
      {
        $av_html= "<a href=\"#$av\">$av</a>";
      }
      elsif ($an =~ /^if\d+/)
      {
        my ($p1, $h1, @p)= split (' ', $av);
        $av_html= "<a href=\"#$p1\">$p1</a> " . join (' ', $h1, @p);
	push (@{$HOSTS{$h1}}, $on);
        push (@{$NETS{$p1}}, $on);
      }
      elsif ($an eq 'location'
             && ($ot eq 'script'
                 ## || $ot eq 'nim_script'  TODO: this is a directory!
                 || $ot eq 'exclude_files'
                )
            )
      {
        push (@copy_files, $av);
        $av_html= "<a href=\"#$av\">$av</a>";
      }

      print F "  <tr>\n    <td>$an</td>\n    <td>$av_html</td>\n</tr>\n";
    }

    print F <<EOX;
</table>

EOX

    # optionally, for objects of type ent, print links to
    # to machines in that network
    if ($ot eq 'ent')
    {
      my @machines;
      @machines= sort @{$NETS{$on}} if (defined ($NETS{$on}));
      if (@machines)
      {
	print F <<EOX;
<h4>machines in this network</h4>
<ul>
EOX
        foreach my $m (@machines)
        {
          print F <<EOX;
  <li><a href="#$m">$m</a></li>
EOX
        }

	print F <<EOX;
</ul>
EOX
      }
    }

    # optionally, if this object type has files that need to be
    # transcribed, they are appended after the objects listing.
    my $fnm;
    foreach $fnm (@copy_files)
    {
      if ($FILE_PRINTED{$fnm})
      {
        my $ptr= $FILE_PRINTED{$fnm};
        print "<p>NOTE: file $fnm printed with object <a href=\"#$ptr\">$ptr</a>.</p>\n";
      }
      else
      {
        $FILE_PRINTED{$fnm}= $on;
        print F <<EOX;
<h4>file $fnm</h4>
<pre>
<table border=0 width="80%">
<tr><td>
EOX

        local *FF;
        if (open (FF, $fnm))
        {
          print "transcribing $fnm\n" if ($verbose);
	  my $ln= 1;
          while (<FF>)
          {
	    chop;
	    print F "<tr><td width=\"3%\">", $ln++,
	            "</td><td bgcolor=\"#", (($ln%2)==1) ? "e0e0e0" : "ffffff", "\">",
		    $_, "</td></tr>\n";
	  }
	  close (FF);
        }
        else
        {
          print F "cant read $fnm\n";
        }

        print F <<EOX;
</td></tr>
</table>
</pre>
EOX
      }
    }
  }

  # TODO: consider to print serial number and OS level here too.
  print F <<EOX;
<h2><a name="host_names">host names</a></h2>

<table border=1>
<tr>
  <th>host name</th>
  <th>object name</th>
</tr>
EOX

  my $hn;
  foreach $hn (sort keys %HOSTS)
  {
    my @on= @{$HOSTS{$hn}};
    my $on;
    foreach $on (@on)
    {
      print F <<EOX;
<tr>
  <td>$hn</td>
  <td><a href=\"#$on\">$on</a></td>
</tr>
EOX
    }
  }

  print F <<EOX;
</table>

<h2><a name="an_stats">attribute name statistics</a></h2>

<table border=1>
<tr>
  <th>count</th>
  <th>attribute name</th>
  <th>object type</th>
</tr>
EOX

  my $an;
  foreach $an (sort keys %CNT_AN)
  {
    my $x= $CNT_AN{$an};
    my $xp;
    foreach $xp (sort keys %$x)
    {
      my $c= $x->{$xp};
      print F <<EOX;
<tr>
  <td>$c</td>
  <td>$an</td>
  <td><a href="#ot_$xp">$xp</a></td>
</tr>
EOX
    }
  }

  print F <<EOX;
</tr>
</table>

</body>
</html>
EOX
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

