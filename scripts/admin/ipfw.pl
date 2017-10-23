#!/usr/bin/perl
# $Id: ipfw.pl,v 1.1 2006/05/05 10:33:06 gonter Exp $

use strict;

my $ME= undef;
my $MY_IP= undef;
my @INTERFACES;
my %INTERFACES;

my $doit= 0;
my $update= 0;
my $show_names= 1;
# my $me= &me; print "me=", join (':', %$me), "\n"; exit (0);

my %CMD_ALLOW= map {$_=>1} qw(allow accept pass permit);
my %CMD_DENY= map {$_=>1} qw(deny drop reset reject);

my $arg;
while ($arg= shift (@ARGV))
{
  if ($arg eq 'add') { &ipfw_add (@ARGV); last; }
  elsif ($arg =~ /^up(date)?/) { $update= 1; last; }
  elsif ($arg eq 'block') { &ipfw_block (@ARGV); last; }
  elsif ($arg eq 'show') { &ipfw_show (@ARGV); last; }
  elsif ($arg eq 'delete') { &ipfw_delete (@ARGV); last; }
  elsif ($arg eq 'bidi') { &ipfw_bidi (@ARGV); last; }
  elsif ($arg eq '-doit') { $doit= 1; }
  elsif ($arg eq '-n') { $show_names= 0; }
  else { &usage; }
}

if ($update)
{
  my $upd= '/usr/sbin/mkfilt -v 4 -u';
  print $upd, "\n";
  system ($upd) if ($doit);
}

# ----------------------------------------------------------------------
sub ipfw_delete
{
  my @num= sort {$b <=> $a} @_;
  my $num;
  foreach $num (@num)
  {
    my $cmd= "/usr/sbin/rmfilt -v 4 -n $num";
    print $cmd, "\n";
    system ($cmd) if ($doit);
    $update++;
  }
}

# ----------------------------------------------------------------------
sub ipfw_show
{
  &me;

  my $cmd= '/usr/sbin/lsfilt -O';

  local *F;
  open (F, $cmd.'|') || die;
  while (<F>)
  {
    chop;

    next if (/^\s*$/);
    # print $_, "\n";

    my ($num, $action, $s_ip, $s_nm, $d_ip, $d_nm,
	$src_routing, $prot,
	$sp_op, $sp_num, $dp_op, $dp_num,
	$scope, $direction, $log, $frag, $tunnel, $if, $auto)
      = split (/\|/);

    if ($action =~ /^\*/)
    {
      printf ("%05d %-8s\n", $num, $action);
      next;
    }

    $action= 'allow' if ($action eq 'permit');
    $prot= 'ip' if ($prot eq 'all');

    printf ("%05d %-8s %-4s ", $num, $action, $prot);
    print join (' ',
		'from', &readable_addr ($s_ip, $s_nm),
		        &readable_port ($sp_op, $sp_num, $prot),
		'to', &readable_addr ($d_ip, $d_nm),
		      &readable_port ($dp_op, $dp_num, $prot),
	       );
    print "\n";
  }
  close (F);
}

# ----------------------------------------------------------------------
sub readable_addr
{
  my ($ip, $nm)= @_;

  return 'any' if ($ip eq '0.0.0.0' && $nm eq '0.0.0.0');
  return 'any' if ($nm eq '0.0.0.0'); # another way to write any
  if ($nm eq '255.255.255.255')
  {
    return 'me' if ($ip eq $MY_IP && $show_names);
    return $ip;
  }

  return $ip.'/24' if ($nm eq '255.255.255.0');
  return $ip.'/16' if ($nm eq '255.255.0.0');
  return $ip.'/8'  if ($nm eq '255.0.0.0');

  return join (':', $ip, $nm);
}

# ----------------------------------------------------------------------
sub readable_port
{
  my ($op, $port, $proto)= @_;

  return undef if ($op eq 'any' && $port eq 0);
  if ($op eq 'eq')
  {
    if ($show_names && ($proto eq 'tcp' || $proto eq 'udp'))
    {
      my $srv= getservbyport ($port, $proto);
      return $srv if ($srv);
    }
    return $port;
  }

  return '>'.$port if ($op eq 'gt');
  return '<'.$port if ($op eq 'lt');
  return '>='.$port if ($op eq 'ge');
  return '<='.$port if ($op eq 'le');
  return '!'.$port if ($op eq 'neq');
  return 'huh?';
}

# ----------------------------------------------------------------------
sub ipfw_block
{
  my @addresses= @_;
  foreach (@addresses)
  {
    &ipfw_add (qw(deny ip from), $_, qw(to me recv));
  }
}

# ----------------------------------------------------------------------
# add rules for bidirectional server operations
# e.g. ipfw bidi smtp
sub ipfw_bidi
{
  foreach (@_)
  {
    &ipfw_add (qw(allow tcp from any to me), $_);
    &ipfw_add (qw(allow tcp from me to any), $_);
  }
}

# ----------------------------------------------------------------------
sub ipfw_add
{
  my $command= shift;

  $command=~ tr/A-Z/a-z/;

  my $action;
     if (exists ($CMD_ALLOW{$command})) { $action= 'P'; }
  elsif (exists ($CMD_DENY{$command})) { $action= 'D'; }
  else { print "unknown command '$command'\n"; return; }

  my $prot= shift;
  $prot=~ tr/A-Z/a-z/;
  $prot= 'all' if ($prot eq 'ip');

  my %s; # source
  my %d; # destination
  my $if= 'all';
  my $log= 'N';
  my ($recv, $xmit)= (1, 1);

  my ($a, $m);
  while ($a= shift (@_))
  {
       if ($a eq 'from')   { $m= 's_ip'; }
    elsif ($a eq 'to')     { $m= 'd_ip'; }
    elsif ($a eq 'via')    { $m= 'via'; }
    elsif ($a eq 'log')    { $log= 'Y'; }
    elsif ($a eq 'recv')   { $xmit= 0; }
    elsif ($a eq 'xmit')   { $recv= 0; }
    elsif ($m eq 's_ip')   { $s{netaddr}=   $a; $m= 's_port'; }
    elsif ($m eq 's_port') { $s{ports}=     $a; $m= 'huh'; }
    elsif ($m eq 'd_ip')   { $d{netaddr}=   $a; $m= 'd_port'; }
    elsif ($m eq 'd_port') { $d{ports}=     $a; $m= 'huh'; }
    elsif ($m eq 'via')    { $if=           $a; $m= 'huh'; }
    elsif ($m eq 'huh') { print "syntax error: '$a'\n"; return undef; }
  }

  my $ok= &fill_in ($prot, \%s);
  unless ($ok)
  {
    print "no source address specified or invalid\n";
    return;
  }

  $ok= &fill_in ($prot, \%d);
  unless ($ok)
  {
    print "no destination address specified or invalid\n";
    return;
  }

  ## print "## src=", join (':', %s), "\n";
  ## print "## dst=", join (':', %d), "\n";

  my ($sp, $dp);
  foreach $sp (@{$s{PL}})
  {
    foreach $dp (@{$d{PL}})
    {

      my $cmd1= sprintf ("/usr/sbin/genfilt -v 4 -a %s -l '%s' -t '0' -s '%s' -m '%s' -d '%s' -M '%s' -c '$prot' -o '%s' -p '%s' -O '%s' -P '%s' -i '%s'",
         $action, $log,

         $s{netaddr}, $s{netmask},
         $d{netaddr}, $d{netmask},
         $s{PO}, $sp,
         $d{PO}, $dp,
         $if,
      );

      my $cmd2= sprintf ("/usr/sbin/genfilt -v 4 -a %s -l '%s' -t '0' -s '%s' -m '%s' -d '%s' -M '%s' -c '$prot' -o '%s' -p '%s' -O '%s' -P '%s' -i '%s'",
         $action, $log,

         $d{netaddr}, $d{netmask},
         $s{netaddr}, $s{netmask},
         $d{PO}, $dp,
         $s{PO}, $sp,
         $if,
      );

      print $cmd1, "\n" if ($recv);
      print $cmd2, "\n" if ($xmit);
      if ($doit)
      {
        system ($cmd1) if ($recv);
        system ($cmd2) if ($xmit);
      }
      $update++;
    }
  }
}

# ----------------------------------------------------------------------
sub fill_in
{
  my $prot= shift;
  my $p= shift;

  my $a= $p->{netaddr};
  return 0 unless ($a);
  
  $a=~ tr/A-Z/a-z/;
  if ($a eq 'me') { &my_addr ($p); }
  elsif ($a eq 'myc') { &my_net ($p, 'C'); }
  elsif ($a eq 'myb') { &my_net ($p, 'B'); }
  elsif ($a eq 'mya') { &my_net ($p, 'A'); }
  elsif ($a eq 'any') { &any ($p); }

  &evaluate_ports ($prot, $p);

  return 1;
}

# ----------------------------------------------------------------------
sub evaluate_ports
{
  my $prot= shift;
  my $p= shift;

  if ($p->{ports})
  {
    $p->{PO}= 'eq';
    my @PL= split (',', $p->{ports});
    my $i;
    for ($i= 0; $i <= $#PL; $i++)
    {
      $PL[$i]= getservbyname ($PL[$i], $prot) unless ($PL[$i] =~ /^\d+$/);
    }
    $p->{PL}= \@PL;
  }
  else
  {
    $p->{PO}= 'any';
    $p->{PL}= [0];
  }
}

# ----------------------------------------------------------------------
sub any
{
  my $p= shift;
  $p->{netaddr}= '0.0.0.0';
  $p->{netmask}= '0.0.0.0';
}

# ----------------------------------------------------------------------
sub my_addr
{
  my $p= shift;
  my $me= &me;

  $p->{netaddr}= $me->{netaddr};
  $p->{netmask}= '255.255.255.255';
}

# ----------------------------------------------------------------------
sub my_net
{
  my $p= shift;
  my $size= shift;

  my $me= &me;
  ## print "## ", join (':', %$me), "\n";

# ZZZ
  my @ip= split (/\./, $me->{netaddr});
  ## print "##### ", join (':', @ip), "\n";
  my @NM= (255, 255, 255, 255);
  if ($size eq 'C') {                 $ip[3]=                 $NM[3]= 0; }
  if ($size eq 'B') {         $ip[2]= $ip[3]=         $NM[2]= $NM[3]= 0; }
  if ($size eq 'A') { $ip[1]= $ip[2]= $ip[3]= $NM[1]= $NM[2]= $NM[3]= 0; }

  $p->{netaddr}= join ('.', @ip);
  $p->{netmask}= join ('.', @NM);
}

# ----------------------------------------------------------------------
sub me
{
  &parse_ifconfig () unless (defined ($ME));
  if ($ME) { $MY_IP= $ME->{netaddr}; }
  $ME;
}

# ----------------------------------------------------------------------
sub parse_ifconfig
{
  my $res= `/usr/sbin/ifconfig -l`;
  chop ($res);
  my @INTERFACES= split (' ', $res);
  my $if;
  foreach $if (@INTERFACES)
  {
    my $IF= $INTERFACES{$if}= &get_interface_attr ($if);
    $ME= $IF if (!defined ($ME) && !($if =~ /^lo/));
  }
}

# ----------------------------------------------------------------------
sub get_interface_attr
{
  my $if= shift;
  my $cmd= "/usr/sbin/lsattr -El '$if'";
  ## print "## $cmd\n";
  my @res= split ("\n", `$cmd`);
  my %obj= ( 'if' => $if );
  foreach (@res)
  {
    chop;
    my ($an, $av)= split;
    $obj{$an}= $av;
  }
  \%obj;
}

