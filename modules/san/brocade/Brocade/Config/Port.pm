# $Id: Port.pm,v 1.2 2011/06/26 07:55:40 gonter Exp $

=head1 NAME

  Brocade::Config::Port  --  switch port configuration data

=head1 SYNOPSIS

=head2 $port_object->print_port_stats (*FO, $timestamp);

=cut

package Brocade::Config::Port;

my @port_info=
(
  'Slot', 'Port', 'Index', 'Area', 'name',
  'State', 'Media', 'Type', 'Speed'
);

my @port_stats=
qw( Interrupts Link_failure Frjt Unknown Loss_of_sync Fbsy Lli
    Loss_of_sig Proc_rqrd Protocol_err Timed_out Invalid_word
    Rx_flushed Invalid_crc Tx_unavail Delim_err Free_buffer Address_err
    Overrun Lr_in Suspended Lr_out Parity_err Ols_in 2_parity_err
    Ols_out CMI_bus_err
   );

my @port_stats_32bit=
(
  {
    'desc' => '4-byte words transmitted',
    'counter' => 'stat_wtx',
    'idx' => 0
  },
  {
    'desc' => '4-byte words received',
    'counter' => 'stat_wrx',
    'idx' => 1
  },
  {
    'desc' => 'Frames transmitted',
    'counter' => 'stat_ftx',
    'idx' => 2
  },
  {
    'desc' => 'Frames received',
    'counter' => 'stat_frx',
    'idx' => 3
  },
  {
    'desc' => 'Class 2 frames received',
    'counter' => 'stat_c2_frx',
    'idx' => 4
  },
  {
    'desc' => 'Class 3 frames received',
    'counter' => 'stat_c3_frx',
    'idx' => 5
  },
  {
    'desc' => 'Link control frames received',
    'counter' => 'stat_lc_rx',
    'idx' => 6
  },
  {
    'desc' => 'Multicast frames received',
    'counter' => 'stat_mc_rx',
    'idx' => 7
  },
  {
    'desc' => 'Multicast timeouts',
    'counter' => 'stat_mc_to',
    'idx' => 8
  },
  {
    'desc' => 'Multicast frames transmitted',
    'counter' => 'stat_mc_tx',
    'idx' => 9
  },
  {
    'desc' => 'Time R_RDY high priority',
    'counter' => 'tim_rdy_pri',
    'idx' => 10
  },
  {
    'desc' => 'Time BB credit zero',
    'counter' => 'tim_txcrd_z',
    'idx' => 11
  },
  {
    'desc' => 'Encoding errors inside of frames',
    'counter' => 'er_enc_in',
    'idx' => 12
  },
  {
    'desc' => 'Frames with CRC errors',
    'counter' => 'er_crc',
    'idx' => 13
  },
  {
    'desc' => 'Frames shorter than minimum',
    'counter' => 'er_trunc',
    'idx' => 14
  },
  {
    'desc' => 'Frames longer than maximum',
    'counter' => 'er_toolong',
    'idx' => 15
  },
  {
    'desc' => 'Frames with bad end-of-frame',
    'counter' => 'er_bad_eof',
    'idx' => 16
  },
  {
    'desc' => 'Encoding error outside of frames',
    'counter' => 'er_enc_out',
    'idx' => 17
  },
  {
    'desc' => 'Invalid ordered set',
    'counter' => 'er_bad_os',
    'idx' => 18
  },
  {
    'desc' => 'Class 3 frames discarded due to timeout',
    'counter' => 'er_c3_timeout',
    'idx' => 19
  },
  {
    'desc' => 'Class 3 frames discarded due to destination unreachable',
    'counter' => 'er_c3_dest_unreach',
    'idx' => 20
  },
  {
    'desc' => 'Other discards',
    'counter' => 'er_other_discard',
    'idx' => 21
  },
  {
    'desc' => 'Class 3 frames discarded due to zone mismatch',
    'counter' => 'er_zone_discard',
    'idx' => 22
  },
  {
    'desc' => 'Crc error with good eof',
    'counter' => 'er_crc_good_eof',
    'idx' => 23
  },
  {
    'desc' => 'Invalid ARB',
    'counter' => 'er_inv_arb',
    'idx' => 24
  },
  {
    'desc' => 'loop_open',
    'counter' => 'open',
    'idx' => 25
  },
  {
    'desc' => 'loop_transfer',
    'counter' => 'transfer',
    'idx' => 26
  },
  {
    'desc' => 'FL_Port opened',
    'counter' => 'opened',
    'idx' => 27
  },
  {
    'desc' => 'tenancies stopped due to starvation',
    'counter' => 'starve_stop',
    'idx' => 28
  },
  {
    'desc' => 'number of times FL has the tenancy',
    'counter' => 'fl_tenancy',
    'idx' => 29
  },
  {
    'desc' => 'number of times NL has the tenancy',
    'counter' => 'nl_tenancy',
    'idx' => 30
  },
  {
    'desc' => 'zero tenancy',
    'counter' => 'zero_tenancy',
    'idx' => 31
  }
);

my @port_stats_64bit=
(
  {
    'desc' => 'top_int : 4-byte words transmitted',
    'counter' => 'stat64_wtx_upper',
    'idx' => 0
  },
  {
    'desc' => 'bottom_int : 4-byte words transmitted',
    'counter' => 'stat64_wtx_lower',
    'idx' => 1
  },
  {
    'desc' => 'top_int : 4-byte words received',
    'counter' => 'stat64_wrx_upper',
    'idx' => 2
  },
  {
    'desc' => 'bottom_int : 4-byte words received',
    'counter' => 'stat64_wrx_lower',
    'idx' => 3
  },
  {
    'desc' => 'top_int : Frames transmitted',
    'counter' => 'stat64_ftx_upper',
    'idx' => 4
  },
  {
    'desc' => 'bottom_int : Frames transmitted',
    'counter' => 'stat64_ftx_lower',
    'idx' => 5
  },
  {
    'desc' => 'top_int : Frames received',
    'counter' => 'stat64_frx_upper',
    'idx' => 6
  },
  {
    'desc' => 'bottom_int : Frames received',
    'counter' => 'stat64_frx_lower',
    'idx' => 7
  },
  {
    'desc' => 'top_int : Class 2 frames received',
    'counter' => 'stat64_c2_frx_upper',
    'idx' => 8
  },
  {
    'desc' => 'bottom_int : Class 2 frames received',
    'counter' => 'stat64_c2_frx_lower',
    'idx' => 9
  },
  {
    'desc' => 'top_int : Class 3 frames received',
    'counter' => 'stat64_c3_frx_upper',
    'idx' => 10
  },
  {
    'desc' => 'bottom_int : Class 3 frames received',
    'counter' => 'stat64_c3_frx_lower',
    'idx' => 11
  },
  {
    'desc' => 'top_int : Link control frames received',
    'counter' => 'stat64_lc_rx_upper',
    'idx' => 12
  },
  {
    'desc' => 'bottom_int : Link control frames received',
    'counter' => 'stat64_lc_rx_lower',
    'idx' => 13
  },
  {
    'desc' => 'top_int : Multicast frames received',
    'counter' => 'stat64_mc_rx_upper',
    'idx' => 14
  },
  {
    'desc' => 'bottom_int : Multicast frames received',
    'counter' => 'stat64_mc_rx_lower',
    'idx' => 15
  },
  {
    'desc' => 'top_int : Multicast timeouts',
    'counter' => 'stat64_mc_to_upper',
    'idx' => 16
  },
  {
    'desc' => 'bottom_int : Multicast timeouts',
    'counter' => 'stat64_mc_to_lower',
    'idx' => 17
  },
  {
    'desc' => 'top_int : Multicast frames transmitted',
    'counter' => 'stat64_mc_tx_upper',
    'idx' => 18
  },
  {
    'desc' => 'bottom_int : Multicast frames transmitted',
    'counter' => 'stat64_mc_tx_lower',
    'idx' => 19
  },
  {
    'desc' => 'top_int : Time R_RDY high priority',
    'counter' => 'tim64_rdy_pri_upper',
    'idx' => 20
  },
  {
    'desc' => 'bottom_int : Time R_RDY high priority',
    'counter' => 'tim64_rdy_pri_lower',
    'idx' => 21
  },
  {
    'desc' => 'top_int : Time BB_credit zero',
    'counter' => 'tim64_txcrd_z_upper',
    'idx' => 22
  },
  {
    'desc' => 'bottom_int : Time BB_credit zero',
    'counter' => 'tim64_txcrd_z_lower',
    'idx' => 23
  },
  {
    'desc' => 'top_int : Encoding errors inside of frames',
    'counter' => 'er64_enc_in_upper',
    'idx' => 24
  },
  {
    'desc' => 'bottom_int : Encoding errors inside of frames',
    'counter' => 'er64_enc_in_lower',
    'idx' => 25
  },
  {
    'desc' => 'top_int : Frames with CRC errors',
    'counter' => 'er64_crc_upper',
    'idx' => 26
  },
  {
    'desc' => 'bottom_int : Frames with CRC errors',
    'counter' => 'er64_crc_lower',
    'idx' => 27
  },
  {
    'desc' => 'top_int : Frames shorter than minimum',
    'counter' => 'er64_trunc_upper',
    'idx' => 28
  },
  {
    'desc' => 'bottom_int : Frames shorter than minimum',
    'counter' => 'er64_trunc_lower',
    'idx' => 29
  },
  {
    'desc' => 'top_int : Frames longer than maximum',
    'counter' => 'er64_toolong_upper',
    'idx' => 30
  },
  {
    'desc' => 'bottom_int : Frames longer than maximum',
    'counter' => 'er64_toolong_lower',
    'idx' => 31
  },
  {
    'desc' => 'top_int : Frames with bad end-of-frame',
    'counter' => 'er_bad_eof_upper',
    'idx' => 32
  },
  {
    'desc' => 'bottom_int : Frames with bad end-of-frame',
    'counter' => 'er_bad_eof_lower',
    'idx' => 33
  },
  {
    'desc' => 'top_int : Encoding error outside of frames',
    'counter' => 'er64_enc_out_upper',
    'idx' => 34
  },
  {
    'desc' => 'bottom_int : Encoding error outside of frames',
    'counter' => 'er64_enc_out_lower',
    'idx' => 35
  },
  {
    'desc' => 'top_int : Class 3 frames discarded',
    'counter' => 'er64_disc_c3_upper',
    'idx' => 36
  },
  {
    'desc' => 'bottom_int : Class 3 frames discarded',
    'counter' => 'er64_disc_c3_lower',
    'idx' => 37
  },
  {
    'desc' => 'Tx frame rate (fr/sec)',
    'counter' => 'stat64_rateTxFrame',
    'idx' => 38
  },
  {
    'desc' => 'Rx frame rate (fr/sec)',
    'counter' => 'stat64_rateRxFrame',
    'idx' => 39
  },
  {
    'desc' => 'Tx peak frame rate (fr/sec)',
    'counter' => 'stat64_rateTxPeakFrame',
    'idx' => 40
  },
  {
    'desc' => 'Rx peak frame rate (fr/sec)',
    'counter' => 'stat64_rateRxPeakFrame',
    'idx' => 41
  },
  {
    'desc' => 'Tx Byte rate (bytes/sec)',
    'counter' => 'stat64_rateTxByte',
    'idx' => 42
  },
  {
    'desc' => 'Rx Byte rate (Bytes/sec)',
    'counter' => 'stat64_rateRxByte',
    'idx' => 43
  },
  {
    'desc' => 'Tx peak Byte rate (Bytes/sec)',
    'counter' => 'stat64_rateTxPeakByte',
    'idx' => 44
  },
  {
    'desc' => 'Rx peak Byte rate (Bytes/sec)',
    'counter' => 'stat64_rateRxPeakByte',
    'idx' => 45
  },
  {
    'desc' => 'top_int : 4-byte words transmitted',
    'counter' => 'stat64_PRJTFrames_upper',
    'idx' => 46
  },
  {
    'desc' => 'bottom_int : 4-byte words transmitted',
    'counter' => 'stat64_PRJTFrames_lower',
    'idx' => 47
  },
  {
    'desc' => 'top_int : 4-byte words transmitted',
    'counter' => 'stat64_PBSYFrames_upper',
    'idx' => 48
  },
  {
    'desc' => 'bottom_int : 4-byte words transmitted',
    'counter' => 'stat64_PBSYFrames_lower',
    'idx' => 49
  },
  {
    'desc' => 'top_int : 4-byte words transmitted',
    'counter' => 'stat64_inputBuffersFull_upper',
    'idx' => 50
  },
  {
    'desc' => 'bottom_int : 4-byte words transmitted',
    'counter' => 'stat64_inputBuffersFull_lower',
    'idx' => 51
  },
  {
    'desc' => 'top_int : 4-byte words transmitted',
    'counter' => 'stat64_rxClass1Frames_upper',
    'idx' => 52
  },
  {
    'desc' => 'bottom_int : 4-byte words transmitted',
    'counter' => 'stat64_rxClass1Frames_lower',
    'idx' => 53
  }
);

my @extra= qw( epoch options switch );

sub print_port_stats_header
{
  local *FO= shift;
  my $extra= shift;

  foreach my $label (@extra, @port_info, @port_stats)
  {
    print FO $label, ";";
  }

  foreach my $d (@port_stats_32bit, @port_stats_64bit)
  {
    print FO $d->{'counter'}, ";";
  }
  print FO "\n";
}

sub print_port_stats
{
  my $po= shift;
  local *FO= shift;
  my $extra= shift;

  # print __LINE__, " po: ", main::Dumper ($po), "\n";
  foreach my $val (@$extra)
  {
    print FO $val, ";";
  }

  foreach my $label (@port_info)
  {
    print FO $po->{$label}, ";";
  }

  my ($ps, $s32, $s64)= map { $po->{$_}; } qw(portshow portstatsshow portstats64show);

  foreach my $label (@port_stats)
  {
    print FO $ps->{$label}, ";";
  }

  # foreach my $d (@port_stats_32bit) { print FO $s32->[$d->{'idx'}], ";"; }
  # foreach my $d (@port_stats_64bit) { print FO $s64->[$d->{'idx'}], ";"; }
  map { print FO $_, ";" } @$s32;
  map { print FO $_, ";" } @$s64;
  print FO "\n";
}


1;

__END__

=head1 TODO

compare current port statistics descriptions with those counters we
already know about and included in this module.

