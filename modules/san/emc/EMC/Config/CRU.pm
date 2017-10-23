#
# $Id: CRU.pm,v 1.13 2010/06/09 19:40:17 gonter Exp $
#

package EMC::Config::CRU;

use strict;

=pod

=head1 NAME

EMC::Config::CRU  --  EMC CRU configuraton

=cut

# Thes parts should be in state 'Present', everything else is probably wrong
my %CRU_PARTS=
(
  'DAE3P' =>
  [ 
    'Fan A State',   'Fan B State',
    'LCC A State',   'LCC B State',
    'Power A State', 'Power B State',
  ],

  'SPE2' =>
  [
    'SP A State',    'SP B State',
    'Fan A State',   'Fan B State',    'Fan C State',
    'Power A State', 'Power B State',
    'SPS A State',   'SPS B State',
    'SPS A Cabling State', 'SPS B Cabling State',
  ],

  'SPE5' =>
  [
    'SP A State',    'SP B State',
    'Power A0 State','Power B0 State',
    'Power A1 State','Power B1 State',
    'SPS A State',   'SPS B State',
    'SPS A Cabling State', 'SPS B Cabling State',
  ],

  'DPE4AX' => # AX4 Disk and Processor Enclosure
  [
    'SP A State',    'SP B State',
    # 'Fan A State',   'Fan B State',
    'Power Supply 1 State', 'Power Supply 2 State',
  ],

  'DAE4AX' => # AX4 Disk Array Enclosure
  [
    # 'Fan A State',   'Fan B State',
    'LCC A State',   'LCC B State',
    'Power Supply 1 State', 'Power Supply 2 State',
  ],
);
# apparently, navicli version 22 showed a Fan D, this not longer shown   'Fan D State',

sub new
{
  my $class= shift;

  my $cru_type= shift;
  my $bus= shift;
  my $encl= shift;

  my $do=
  {
    'cru_type' => $cru_type,
    'bus'  => $bus,
    'encl' => $encl,
  };

  bless $do, $class;
  $do;
}

sub analyze
{
  my $cl_or_obj= shift;
  my $item= shift;

  # print __LINE__, " cl_or_obj='$cl_or_obj'\n";

  my $tag= $item->[0];
  my $cru_type= 'invalid';
  my ($bus, $encl, $label, $extra);
  my @extra;
  my @extended;

  if ($tag =~ m#(SPE\d+) Enclosure SPE#)
  {
    $label= $cru_type= $1;
  }
  elsif ($tag =~ m#(DAE3P) Bus (\d+) Enclosure (\d+)(.*)#)
  {
    ($cru_type, $bus, $encl, $extra)= ($1, $2, $3, $4);
    unless ($extra =~ /^\s*$/)
    {
      $extra=~ s/^ *//;
      $extra=~ s/ *$//;
## print __LINE__, " >>>>> extra: '$extra'\n";
      push (@extra, $extra);
    }
    $label= join ('_', $cru_type, $bus, $encl);
    
  }
  elsif ($tag =~ m#(D[AP]E4AX) Enclosure (\d+)(.*)#)
  { # DAE4AX Enclosure 4
    ($cru_type, $encl, $extra)= ($1, $2, $3);
    $bus= 0;
    $label= join ('_', $cru_type, $bus, $encl);
  }
  else { return ('invalid', $tag, $item); }

  my $do= new EMC::Config::CRU ($cru_type, $bus, $encl);
  $do->{'label'}= $label;
## print __LINE__, " label='$label'\n";

  my @l= @$item;
  shift (@l);

  foreach my $l (@l)
  {
      $l=~ s/^ *//;
      $l=~ s/ *$//;
## print __LINE__, " >>> l='$l'\n";

    if ($l =~ /^(Enclosure SPE|Bus \d+ Enclosure \d+|Enclosure \d+)\s+([\w #]+):\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($2, $3);
      $do->{$kw}= $val;
    }
    elsif ($l =~ /^(SP (A|B) State|Power Supply \d State):\s*(.+)\s*$/)
    {
      my ($kw, $val)= ($1, $3);
      $do->{$kw}= $val;
    }
    elsif ($l =~ m#\(Bus (\d+) Enclosure (\d+) : (Faulted)(.*)\)$#)
    {
      # e.g. (Bus 1 Enclosure 4 : Faulted)
      # e.g. (Bus 1 Enclosure 4 : Faulted; Bus 1 Enclosure 4 Disk 8 : Removed)
      my ($bus, $encl, $state, $extra)= ($1, $2, $3, $4);
      push (@extended, $l);
    }
    elsif ($l =~ m#^\(Enclosure SPE : Cabling information differs between SPs; may indicate disconnected cabinets.\)#
           || $l =~ m#^\(Enclosure SPE : Faulted; Enclosure SPE SPS . : Testing\)#
          )
    {
      push (@extended, $l);
    }
    elsif ($l =~ m#^\(Enclosure SPE : Cabling information differs between SPs; may indicate disconnected cabinets.\)#)
    {
      push (@extended, $l);
    }
    else
    {
print __LINE__, " >>> '$l'\n";
# e.g.: 154 >>> '(Enclosure SPE : Faulted; Enclosure SPE SPS B : Testing)'
      push (@extended, $l) if ($l);
    }
  }
  $do->{'extra'}= \@extra if (@extra);
  $do->{'extended'}= \@extended if (@extended);

  ($cru_type, $label, $do);
}

=pod

=head2 $cru->state ()

Check CRU parameters for unexpected conditions.

=cut

sub state
{
  my $obj= shift;

  my ($label, $ty, $bus, $encl, $extra, $extended)=
     map { $obj->{$_} } ('label', 'cru_type', 'bus', 'encl',
                         'extra', 'extended');

  my @attn;
  my $CRU_parts= $CRU_PARTS{$ty};
  push (@attn, "unknown CRU type '$ty'") unless (defined ($CRU_parts));

  foreach my $part (@$CRU_parts)
  {
    my $state= $obj->{$part};
    push (@attn, "$part is $state") unless ($state eq 'Present' || $state eq 'Valid');
  }
  push (@attn, @$extra) if (defined ($extra));

  my $attn= (@attn) ? 'ATTN: ' . join (', ', @attn) : 'OK';

  ($label, $ty, $bus, $encl, $attn, $extended);
}

1;

__END__
