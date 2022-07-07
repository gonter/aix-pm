=pod
# $Id: printer.pm,v 1.1 2007/03/08 06:11:45 gonter Exp $

=head1 NAME

  AIX::printer

=head1 SYNOPSIS

  use AIX::printer;
  my $p= new AIX::printer ('printer' => 'my-printer');

=head1 DESCRIPTION

=cut

use strict;

package AIX::printer;

my $LPSTAT= '/usr/bin/lpstat';
my $LPRM= '/usr/bin/lprm';
my $QADM= '/usr/bin/qadm';
my %QADM_FLAGS= map { $_ => $_ } qw(D K U X);


sub new
{
  my $class= shift;

  my $obj= {};
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

sub get
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

=head2 lpstat

  get status and job list of given printer

=cut

sub lpstat
{
  my $obj= shift;

  my $printer= $obj->{'printer'} or return undef;
  my $cmd= "$LPSTAT -W -p'$printer'";

  local (*FI);
  open (FI, $cmd . '|') or return undef;
  my @lines= <FI>;
  close (FI);
  chop (@lines);

  my $hdr= shift @lines;
  my $sep= shift @lines;
  my $pst= shift @lines;

  print ">>>> hdr='$hdr'\n";
  print ">>>> sep='$sep'\n";
  print ">>>> pst='$pst'\n";

  my @field= split (' ', $hdr);
  my $pat= $sep;
  $pat=~ s/-/./g;
  $pat=~ s/( +)/)$1(/g;
  $pat= '(' . $pat . ')';

  print ">>>> pat='$pat'\n";

  my ($queue, $dev, $status)= split (' ', $pst);

  my %jobs= ();
  my @extra= ();

  $obj->{'status'}= $status;
  $obj->{'queue'}= $queue;
  $obj->{'dev'}= $dev;
  $obj->{'jobs'}= \%jobs;
  $obj->{'extra'}= \@extra;
  my $job_count= 0;

  while (my $l= shift (@lines))
  {
    print ">>>>>> l='$l'\n";

    if ($l =~ /$pat/)
    {
      my @j= ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
         @j= map { $_ =~ s/ *$//g; $_ =~ s/^ *//g; $_; } @j; # strip blanks

      my ($j_q, $j_dev, $j_st, $j_id, $j_fnm, $j_owner, $j_pp, $j_pct,
          $j_blk, $j_cp, $j_rnk
         )= @j;

      my $job= {};
      foreach (my $i= 0; $i <= $#field; $i++) { $job->{$field[$i]}= $j[$i]; }

      # my $job=
      #  {
      #    'status' => $j_st, 'íd' => $j_id, 'owner' => $j_owner, 'fnm' => $j_fnm,
      #   'pp' => $j_pp, 'pct' => $j_pct, 'blk' => $j_blk, 'cp' => $j_cp, 'rnk' => $j_rnk,
      #   };
      print ">>>> JOB: ", join (':', %$job), "\n";

      $jobs{$j_id}= $job;
      $job_count++;
    }
    else
    {
      push (@extra, $l);
    }
  }

  $obj->{'job_count'}= $job_count;
  ($status, $job_count);
}

=head2 purge_queue

  purge queue of given printer

=cut

sub purge_queue
{
  my $obj= shift;
  my $mode= shift;

  my $printer= $obj->{'printer'} or return undef;

  my $cnt_purged= 0;

  if ($mode eq 'qadm' || $mode eq 'X')
  {
    $obj->qadm ('X');
  }
  elsif ($mode eq 'lprm')
  {
    my $jobs= $obj->{'jobs'};
    foreach my $job_num (sort { $a <=> $b } keys %$jobs)
    {
      my $job= $jobs->{$job_num};
      &main::print_refs (*STDOUT, 'purging job' => $job);
      my $cmd= "$LPRM -P'$printer' '$job_num'";
      print ">>> $cmd\n";
      system ($cmd);
      $cnt_purged++;
    }
  }

  $cnt_purged;
}

=head2 UP

  print printer UP or READY

=cut

sub UP { shift->qadm ('U'); }

=head2 UP

  print printer UP or READY

=cut

sub DOWN { shift->qadm ('D'); }

=head2 qadm (action)

  performs action on printer; action can either be:
  D .. bring printer down;
  K .. bring printer down and end current job;
  U .. bring printer up;
  X .. cancel all jobs

=cut

sub qadm
{
  my $obj= shift or return undef;
  my $flag= shift or return undef;

  return undef unless (exists ($QADM_FLAGS{$flag}));

  my $printer= $obj->{'printer'} or return undef;

  my $cmd= "$QADM -$flag'$printer'";

  print ">>> $cmd\n";
  system ($cmd);
}

1;

__END__

=head1 BUGS

  Too much diagnostic output.

=head1 REFERENCES

  AIX manual pages for lpstat, qadm, lprm, etc.

=head1 AUTHOR

  Gerhard Gonter <ggonter@cpan.org>

=over
