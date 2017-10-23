#
# expect module to interact with NetApp filers
#
# $Id: Expect.pm,v 1.4 2012/04/16 17:02:42 gonter Exp $

=pod

=head1 NAME

NetApp::Expect

=head1 SYNOPSIS

  use NetApp::Expect;
  my $be= new NetApp::Expect ('filer' => $filer, 'user' => $user, 'pass' => $pass);
  my $logged_in= $be->login ();
  die "not logged in" unless ($logged_in);

=head1 DESCRIPTION

=cut

package NetApp::Expect;

use strict;
use Expect;

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
## print ">>> set: par='$par' val='$par{$par}'\n";
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

sub login
{
  my $obj= shift;

  my ($filer, $user, $pass, $keyfile, $timeout, $verbose, $debug)= map { $obj->{$_} } qw(filer user pass keyfile timeout verbose debug);
  $timeout= 300 unless (defined ($timeout));

  my $cmd= "ssh";
  $cmd .= " -i '$keyfile'" if (defined ($keyfile));
  $cmd .= " -l '$user' '$filer'";
  print ">>> cmd='$cmd'\n";

  my $exp= new Expect ($cmd);

  print ">>>> exp='$exp'\n";
  if (defined ($debug))
  {
    print "setting debug level to '$debug'\n";
    $exp->debug($debug);
  }

  my $logged_in= 0;

  my $spawn_ok= 0;
  $exp->expect ($timeout,
    [
      timeout => sub { $obj->error= "timeout: no login."; }
    ],
    [
      'Permission denied, please try again.' => sub { $obj->{'error'}= "Permission denied!"; }
    ],
    [  
      'password: $',
      sub {
        $spawn_ok = 1;
        my $fh = shift;
        print $fh "$pass\n";
        exp_continue;
      }
    ],

    # interact with ssh key handling
    [
      'Are you sure you want to continue connecting \(yes\/no\)\?',
      sub {
        $spawn_ok = 1;
        my $fh = shift;
        print $fh "yes\n";
        exp_continue;
      }
    ],

    [
      '-re', qr'> $', # wait for prompt, then exit this expect loop
      sub {
	$logged_in= 1;
        $obj->{'exp'}= $exp;
      }
    ],
  );

END:
  $obj->{'logged_in'}= $logged_in;
}

=cut

=head2 $be->interact ();

Allow commands to be executed interactively until user hits EOF.

=cut

sub interact
{
  my $obj= shift;
  my ($exp, $timeout)= map { $obj->{$_} } qw(exp timeout);
  $exp->interact ();
}

=cut

=head2 $be->actions (list-of-commands);

Perform the (...) commands given in the argument list.

Returns output of these commands as a list of list of lines.

Example:
  ...

=cut

sub actions
{
  my $obj= shift;
  my @actions= @_;

  unless ($obj->{'logged_in'})
  {
    $obj->login ();
    unless ($obj->{'logged_in'})
    {
      die "cant login to $obj->{'filer'}";
    }
  }

  my ($exp, $timeout)= map { $obj->{$_} } qw(exp timeout);
  my @res= ();

  EXPECTATION: while (my $c= shift (@actions))
  {
    ## print __FILE__, ':', __LINE__, " >>>> c='$c'\n";
    my $done= 0;

    if ($c eq 'interact') { $exp->interact (); }
    else
    {
      $exp->send ("$c\n");
      $exp->expect ($timeout,
        [
	  eof => sub {
	    print "EOF reached ". __FILE__, ':', __LINE__, "\n";
            $done= 1;
	  }
        ],
        [
          '-re', qr'^.+> $', # wait for prompt, then exit this expect loop
	  sub
	  {
	    my $b= $exp->before (); # output of the last command
	    my $m= $exp->match ();  # just the next command prompt
            $b=~ s/\r//g;
	    my @b= split (/\n/, $b);
	    $b[0]= $m . $b[0];      # combine prompt and the command

	    ## print ">>>> b=[$b]\n";
	    ## print ">>>> m=[$m]\n";
	    ## print ">>>> b0=[$b[0]]\n";

	    push (@res, \@b);
	  }
        ],
      );
    }

    last EXPECTATION if ($done);
  }

  (wantarray) ? @res : \@res;
}

1;

__END__

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR
   
Gerhard Gonter E<lt>ggonter@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2012 by Gerhard Gonter
  
This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
    
=over

