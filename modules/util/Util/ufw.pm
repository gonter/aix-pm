#!/usr/bin/perl

use strict;

package Util::ufw;

sub new
{
  my $class= shift;

  my $self=
  {
    status => undef,
  };
  bless $self, $class;
  $self->set(@_);
  $self;
}

sub set
{
  my $self= shift;
  my %pars= @_;

  foreach my $par (keys %pars)
  {
    $self->{$par}= $pars{$par};
  }
}

sub status
{
  my $self= shift;

  $self= Util::ufw->new(@_) if ($self eq 'Util::ufw');

  open (UFW, '-|:utf8', 'ufw', 'status', 'numbered') or die;

  my $st= 0;

  my @rules= (); $self->{rules}= \@rules;
  my %si4=   (); $self->{src_ipv4}= \%si4;
  my %si4c=  (); $self->{src_ipv4_cidr}= \%si4c;
  my ($rule_number, $text);
  while (<UFW>)
  {
    chop;
    # print __LINE__, " ufw: st=[$st] [$_]\n";

    if ($st == 0)
    {
      if ($_ =~ /^Status: (.+)/) { $self->{status}= $1; }
      $st++;
    }
    elsif ($st == 1)
    {
      if ($_ =~ /^[ \-]+$/) { $st= 2; }
    }
    elsif ($st == 2) # rules section
    {
      if ($_ eq '') { $st= 3; }
      elsif ($_ =~ /^\[\s*(\d+)\]\s*(.*)/)
      {
        ($rule_number, $text)= ($1, $2);

        my %rule= ( rule_number => $rule_number, line => $_, addressing => 'ipv4' );

        my @t= split(' ', $text);
        my $rst= 0;
        while (my $t= shift (@t))
        {
          if ($rst == 0)
          {
            $rule{dst}= $t;
            if ($t[0] eq '(v6)') { $rule{addressing}= 'ipv6'; shift(@t); }
            $rst= 1;
          }
          elsif ($rst == 1)
          {
            $t .= ' '. shift(@t) if ($t[0] eq 'IN' || $t[0] eq 'OUT');
            my $policy= 'unknown';

               if ($t eq 'DENY IN')   { $policy= 'deny' }
            elsif ($t eq 'REJECT IN') { $policy= 'reject' }
            elsif ($t eq 'ALLOW IN')  { $policy= 'allow' }

            $rule{action}= $t;
            $rule{policy}= $policy;
            $rst= 2;
          }
          elsif ($rst == 2)
          {
            $rule{src}= $t;
            if ($t[0] eq '(v6)') { $rule{addressing}= 'ipv6'; shift(@t); }

            if ($t =~ /^[\d\.\/]+$/)
            {
              if ($t =~ /\//) { $rule{is_ipv4_cidr}= 1; push (@{$si4c{$t}}, $rule_number); }
              else  { $rule{is_ipv4}= 1; push (@{$si4{$t}}, $rule_number); }
            }
            elsif ($t eq 'Anywhere') { $rule{is_world}= 1; }
            else { $rule{unkown_src}= 1; }

            $rst= 3;
          }
          elsif ($rst == 3)
          {
            if ($t eq '(log)') { $rule{log}= 1; }
	    elsif ($t eq '#') { $rule{comment}= join(' ', @t); @t= (); }
            else { push (@{$rule{junk}}, $t) }
          }
        }
        push (@rules, \%rule);
      }
      else
      {
        print __LINE__, "unknown line=[$_]\n";
      }
    }
  }
  close(UFW);

  $self;
}

sub has_rules_ipv4
{
  my $self= shift;
  my $ipv4= shift;

  if (exists ($self->{src_ipv4}->{$ipv4}))
  {
    return ($self->{src_ipv4}->{$ipv4});
  }

  return undef;
}

sub get_rule
{
  my $self= shift;
  my $number= shift;

  return ($self->{rules}->[$number-1]);
}

sub get_ipv4_cidr_hash
{
  my $self= shift;
  return $self->{src_ipv4_cidr};
}

sub block
{
  my $self= shift;
  my $ip= shift;

  my $c= $self->{config};
  # print __LINE__, " c: ", main::Dumper($c);

  ufw($c->{block_policy}, $ip, $c->{log}, $c->{insert_position});
}

sub remove_rule
{
  my $self= shift;
  my $num= shift;
  my @cmd= ('/usr/sbin/ufw', '--force', 'delete', $num);
  print __LINE__, " remove_rule: ", join(' ', @cmd), "\n";
  system (@cmd);
}

sub ufw
{
  my $action= shift;
  my $ip= shift;
  my $log= shift;
  my $pos= shift;

  my @cmd= ('/usr/sbin/ufw');
  push (@cmd, 'insert', $pos) if (defined ($pos));
  push (@cmd, $action);
  push (@cmd, 'log') if ($log);
  push (@cmd, 'from', $ip);
  print __LINE__, ' ', scalar localtime(time()), ' cmd: ', join(' ', @cmd), "\n";
  system(@cmd);
}

=head2 $rule_number_list= $self->in_firewall_rules($addr);

Check if a given address is listed in the firwall rules and return the
list of rules, if something matches.

TODO: we need probably another element in the return values indication
what type of match this was, e.g. if $addr was a cidr block and it matched
cidr blocks or "collected" several explicit ip addresses or even both.
Also, if $addr was a plain ipv4 address and it matches one or more
existiing cidr rules whould be of interesst.  Maybe this is getting too
complicated after all and should be handled in different methods instead
of just one.

=cut

sub in_firewall_rules
{
  my $self= shift;
  my $ip= shift;

  my @rule_list;
  if ($ip =~ /^[\d\.\/]+$/)
  {
    if ($ip =~ /\//)
    { # TODO: addr to check is cidr
      # later...
      if (exists ($self->{src_ipv4_cidr}->{$ip}))
      {
        my $rule_number_list= $self->{src_ipv4_cidr}->{$ip};
        push (@rule_list, @$rule_number_list);
      }
      # TO CONSIDER: collect all matching IPv4 addresses and deliver them?
    }
    else
    { # plain vanilla ipv4 address
      # print __LINE__, " ip=[$ip]\n";
      if (exists ($self->{src_ipv4}->{$ip}))
      {
        my $rule_number_list= $self->{src_ipv4}->{$ip};
        push (@rule_list, @$rule_number_list);
      }

      # TODO: also check if the ipv4 address to check is convered by a ipv4 cidr block
      my $sc= $self->{src_ipv4_cidr};
      if (defined ($sc))
      {
        my @sc= keys %$sc;
        foreach my $cidr (@sc)
        {
          my $res= Net::CIDR::cidrlookup($ip, $cidr);
          if ($res) { push (@rule_list, @{$sc->{$cidr}}); } # could the be more than one match?
        }
      }
    }
  }

  \@rule_list;
}

sub in_whitelist
{
  my $self= shift;
  my $ip= shift;

  $self->load_whitelists() unless ($self->{_whitelists_loaded});

  if ($ip =~ /^[\d\.\/]+$/)
  {
    if ($ip =~ /\//)
    { # CIDR .... later...
    }
    else
    {
      if (exists ($self->{whitelist_ipv4}) && exists ($self->{whitelist_ipv4}->{$ip}))
      {
        return 'ipv4';
      }

      my $wl_cidr= $self->{whitelist_ipv4_cidr};
      if (defined ($wl_cidr))
      {
        my $res= Net::CIDR::cidrlookup($ip, keys %$wl_cidr);
        return 'ipv4_cidr' if ($res);
      }
    }
  }

  undef;
}

sub load_whitelists
{
  my $self= shift;

  my $c= $self->{config};
  return undef unless (defined ($c));

  if (exists ($c->{whitelist}))
  {
    $self->add_to_whitelist(@{$c->{whitelist}});
  }

  if (exists ($c->{whitelist_file}))
  {
    if (open (FI, '<:utf8', $c->{whitelist_file}))
    {
      my @ips;
      while (<FI>)
      {
        chop;
        next if ($_ =~ /^#/);
        $_=~ s/[ #].*//;
        push (@ips, $_);
      }
      $self->add_to_whitelist(@ips);
    }
    else
    { # no reason to die
      print __LINE__, " can't read whitlist_file=[$c->{whitelist_file}]\m";
    }
  }

  $self->{_whitelists_loaded}= 1;
}

sub add_to_whitelist
{
  my $self= shift;
  my @addr= @_;

  foreach my $ip (@addr)
  {
    if ($ip =~ /^[\d\.]+\/\d+$/)
    {
      $self->{whitelist_ipv4_cidr}->{$ip}++;
    }
    elsif ($ip =~ /^[\d\.]+$/)
    {
      $self->{whitelist_ipv4}->{$ip}++;
    }
    else
    {
      print __LINE__, " unknown address format: [$ip]\n";
    }
  }
}

1;
