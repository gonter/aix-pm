#!/usr/bin/perl

use strict;

use IPC::Run;
use FileHandle;

use Data::Dumper;
$Data::Dumper::Indent= 1;
$Data::Dumper::SortKeys= 1;

# Background Processes
my $j= Journal::Tracking->start();
my $dd;
my $dd_dev;
my $dd_pid;
my $dd_call= 0;

my %disks;
my %scsi_ids;
my $action;

my $delay;
while (1)
{
  my $idle= 1;
  my $l= $j->get_line();

  if (defined ($l))
  {
    $idle= 0;
    if ($l =~ m#kernel: usb (\d+-\d+): New USB device found, idVendor=(\d+), idProduct=(\d+), bcdDevice= ([\d\.]+)#)
    {
      my $disk= { usb_num => $1, idVendor => $2, idProduct => $3, bcdDevice => $4 };
      $disks{$disk->{usb_num}}= $disk;
    }
    elsif ($l =~ m#kernel: usb (\d+-\d+): (Product|Manufacturer|SerialNumber): (.*)#)
    {
      my ($usb_num, $an, $av)= ($1, $2, $3);
      print __LINE__, " usb_num=[$usb_num] an=[$an] av=[$av]\n";
      $av=~ s/\s*$//;

      if (exists ($disks{$usb_num}))
      {
        my $disk= $disks{$usb_num};
        $disk->{$an}= $av;
      }
    }
    elsif ($l =~ m#kernel: scsi (\d+:\d+:\d+:\d): Direct-Access (.*)#)
    {
      my ($scsi_id, $stg)= ($1, $2);
      print __LINE__, " stg=[$stg]\n";
      my @stg= split(' ', $stg);
      print __LINE__, " stg: ", Dumper(\@stg);
      my $disk= find_disk($stg[0], $stg[1]);
      print __LINE__, " disk: ", Dumper($disk);
      if (defined ($disk))
      {
        $disk->{scsi_id}= $scsi_id;
        $disk->{stg}= \@stg;
        $scsi_ids{$scsi_id}= $disk;
      }
    }
    elsif ($l =~ m#kernel: sd (\d+:\d+:\d+:\d+): \[(sd\w+)\] (.*)#)
    {
      my ($scsi_id, $dev, $stg)= ($1, $2, $3);
      my $disk= $scsi_ids{$scsi_id};
      print __LINE__, " scsi_id=[$scsi_id] dev=[$dev] stg=[$stg] disk=[$disk]\n";
      if (defined ($disk))
      {
        $disk->{dev}= $dev;
        push (@{$disk->{dev_info}}, $stg);
        if ($stg eq 'Attached SCSI disk')
        {
          $action= { status => 1, disk => $disk };
          print __LINE__, " action: ", Dumper($action);
          # print __LINE__, " disks: ", Dumper(\%disks);
        }
      }
    }
    elsif ($l =~ m#kernel: sd (\d+:\d+:\d+:\d+): (.*)#)
    {
      my ($scsi_id, $stg)= ($1, $2);
      my $disk= $scsi_ids{$scsi_id};
      if (defined ($disk))
      {
        $disk->{scsi_info}= $stg;
      }
    }
    else
    {
      print __LINE__, " l=[$l]\n"
    }
  }

  if (defined ($action))
  {
    # print __LINE__, " action: ", Dumper($action);
    if ($action->{status} == 1)
    {
      my $disk= $action->{disk};
      print __LINE__, " start_action: disk: ", Dumper($disk);
      $action->{status}= 2;
      $dd_dev= '/dev/' . $disk->{dev};
      $dd= Disk::Dump->start($dd_dev);
      $dd_pid= $dd->get_pid();
      $delay= 0;
      # print __LINE__, " dd: dd_pid=[$dd_pid]", Dumper($dd);
    }
    elsif ($action->{status} == 2)
    {
      my $dd_l= $dd->get_line();
      if (defined ($dd_l))
      {
        $dd_l =~ s/\r//g; # dd status=progress writes the statistics with CR at the start (or end?)
        print __LINE__, " dd_l=[$dd_l]\n";
        $idle= 0;
      }

      if ($dd_call + 10 <= time())
      {
        $dd_call= time();
        my ($offset, $err)= get_dd_offset($dd_pid, $dd_dev);
        if (defined ($err))
        {
          print __LINE__, " lsof: err=[$err]\n";
          print __LINE__, " dd: err=[", ${$dd->{_err}}, "]\n";
          $action->{status}= 3;
        }
        else
        {
          printf("%s %12.3lf\n", (scalar localtime time ()), $offset/1024/1024/1024);
        }
      }
    }
    elsif ($action->{status} == 3)
    {
    }
  }

  if ($idle)
  {
    # print __LINE__, " sleep 1\n";
    sleep(1);
  }

}

exit(0);

while (1)
{
  my ($offset, $err)= get_dd_offset(5834, '/dev/sda');
  last if ($err == 1);
  printf("%s %12.3lf\n", (scalar localtime time ()), $offset/1024/1024/1024);
  sleep(10);
}

exit(0);

sub find_disk
{
  my $manufacturer= shift;
  my $product= shift;

  print __LINE__, " disks: ", Dumper(\%disks);

  foreach my $usb_num (keys %disks)
  {
    my $disk= $disks{$usb_num};
    print __LINE__, " disk: ", Dumper($disk);
    return $disk if ($disk->{Product} eq $product && $disk->{Manufacturer} eq $manufacturer);
  }

  undef;
}

sub get_dd_offset
{
  my $dd_pid= shift;
  my $dev= shift || '/dev/sda';

  my @cmd= ('lsof', '-nPp', $dd_pid);
  my ($in, $out, $err);
  my $not_the_pid= IPC::Run::run(\@cmd, \$in, \$out, \$err) or return (0, 1);
  # print __LINE__, " not_the_pid=[$not_the_pid]\n";

  # print __LINE__, " out=[$out]\n";
  # print __LINE__, " err=[$err]\n";
  
  my $offset= '0x0';

  my @l= split(/\n/, $out);
  while (my $l= shift(@l))
  {
    # print __LINE__, " l=[$l]\n";
    my @f= split(' ', $l);
    if ($f[8] eq $dev)
    {
      $offset= $f[6];
      # print __LINE__, " offset=[$offset]\n";
    }
  }
  close (LSOF);

  return (hex $offset, undef);
}

# ======================================================================
package BackGroundProcess;

sub new
{
  my $class= shift;

  my ($in, $out, $err);
  my $self=
  { 
    _cl => \&capture_output_lines,
    _lines => [],
    _in  => \$in,
    _out => \$out,
    _err => \$err,
  };
  bless ($self, $class);

  sub capture_output_lines
  {
    my $s= shift;
    # print __LINE__, " s=[$s]\n";
    push(@{$self->{_lines}}, split("\n", $s));
  }

  $self;
}

sub get_line
{
  my $self= shift;
  # print __LINE__, " get_line\n";

  unless (@{$self->{_lines}})
  {
    eval {
      IPC::Run::pump_nb($self->{_jcf})
    };

    if ($@)
    {
      print __LINE__, " get_line pump failed with $@\n";
      # print __LINE__, " self: ", main::Dumper($self);
    }
  }

  my $l= shift (@{$self->{_lines}});
  # print __LINE__, " l=[$l]\n";

  $l;
}

sub get_pid
{
  my $self= shift;

  $self->{_jcf}->{KIDS}->[0]->{PID};
}

sub start
{
  my $self= shift;
  my $cmd= shift;

  my $jcf= IPC::Run::start($cmd, $self->{_in}, $self->{_cl}, $self->{_cl}) or return undef;
  # print __LINE__, " jcf=[$jcf]\n";

  $self->{_jcf}= $jcf;
}

# ======================================================================
package Disk::Dump;

sub start
{
  my $class= shift;
  my $dev= shift;

  my $self= BackGroundProcess->new();

  my @cmd= ('dd', 'if=' . $dev, 'of=/dev/null', 'bs=8192', 'status=progress');
  $self->start(\@cmd);

  $self;
}

package Journal::Tracking;

# ======================================================================
sub start
{
  my $self= BackGroundProcess->new();

  my @cmd= ('journalctl', '-f');
  $self->start(\@cmd);

  $self;
}

__END__
COMMAND  PID USER   FD   TYPE DEVICE    SIZE/OFF     NODE NAME
dd      5834 root  cwd    DIR  252,1        4096 10616948 /home/gonter/tmp/sastest
dd      5834 root  rtd    DIR  252,1        4096        2 /
dd      5834 root  txt    REG  252,1       68120 20973349 /usr/bin/dd
dd      5834 root  mem    REG  252,1     6070224 20975281 /usr/lib/locale/locale-archive
dd      5834 root  mem    REG  252,1     2220400 20971780 /usr/lib/x86_64-linux-gnu/libc.so.6
dd      5834 root  mem    REG  252,1      240936 20971732 /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
dd      5834 root    0r   BLK    8,0 0x1b3d3c000      928 /dev/sda
dd      5834 root    1w   CHR    1,3         0t0        5 /dev/null
dd      5834 root    2u   CHR 136,12         0t0       15 /dev/pts/12

14 l=[Jan 15 18:41:44 ggt14a kernel: usb 1-3: new high-speed USB device number 10 using xhci_hcd]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: new SuperSpeed USB device number 8 using xhci_hcd]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: New USB device found, idVendor=1111, idProduct=2222, bcdDevice= 0.61]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: New USB device strings: Mfr=1, Product=2, SerialNumber=3]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: Product: MG03SCA400      ]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: Manufacturer: TOSHIBA ]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb 2-3: SerialNumber: 93J0A09AFV94        ]
14 l=[Jan 15 18:41:45 ggt14a kernel: usb-storage 2-3:1.0: USB Mass Storage device detected]
14 l=[Jan 15 18:41:45 ggt14a kernel: scsi host0: usb-storage 2-3:1.0]
14 l=[Jan 15 18:41:45 ggt14a mtp-probe[43202]: checking bus 2, device 8: "/sys/devices/pci0000:00/0000:00:14.0/usb2/2-3"]
14 l=[Jan 15 18:41:45 ggt14a mtp-probe[43202]: bus: 2, device: 8 was not an MTP device]
14 l=[Jan 15 18:41:45 ggt14a mtp-probe[43213]: checking bus 2, device 8: "/sys/devices/pci0000:00/0000:00:14.0/usb2/2-3"]
14 l=[Jan 15 18:41:45 ggt14a mtp-probe[43213]: bus: 2, device: 8 was not an MTP device]
14 l=[Jan 15 18:41:46 ggt14a kernel: scsi 0:0:0:0: Direct-Access     TOSHIBA  MG03SCA400       0061 PQ: 0 ANSI: 6]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: Attached scsi generic sg0 type 0]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] Very big device. Trying to use READ CAPACITY(16).]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] 7814037168 512-byte logical blocks: (4.00 TB/3.64 TiB)]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] Write Protect is off]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] Mode Sense: 47 00 00 08]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] Write cache: disabled, read cache: enabled, doesn't support DPO or FUA]
14 l=[Jan 15 18:41:46 ggt14a kernel: sd 0:0:0:0: [sda] Attached SCSI disk]
14 l=[Jan 15 18:41:46 ggt14a systemd-udevd[43197]: sda: Process '/usr/bin/unshare -m /usr/bin/snap auto-import --mount=/dev/sda' failed with exit code 1.]
 
