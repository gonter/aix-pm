# $Id: Template.pm,v 1.1 2007/08/31 15:49:19 gonter Exp $

use strict;

use AIX::Software::Package;
use AIX::Software::Fileset;

package AIX::Software::Template;

my %section_begin= map { $_ => 1 } qw(USRFiles USRFiles_catalog Fileset);
my @Package_Fields= ('Package Name', 'Package VRMF', 'Update');

sub new
{
  my $class= shift;

  my $pkg= new AIX::Software::Package;

  my $cat=
  {
    'pkg' => $pkg,
  };

  bless $cat, $class;
  $cat->set (@_);

  $cat;
}

sub set
{
  my $cat= shift;
  my %par= @_;

  my %res;
  foreach my $par (keys %par)
  {
    $res{$par}= $cat->{$par};
    $cat->{$par}= $par{$par};
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

sub parse_catalog
{
  my $cat= shift;
  my $fnm= shift;

  open (FI, $fnm) or die;

  my $pkg= $cat->{'pkg'};
  my $fs= undef;
  my $usr_files= undef;
  my $usr_catalog= undef;

  my $section= 'Package';
  while (<FI>)
  {
    chop;
    ## print ">>>> '$_'\n";
    next if (/^#/ || /^\s*$/);

    s/^\s*//;  # allow indention for readability

    if (exists ($section_begin{$_}))
    {
      $section= $_;

      if ($section eq 'Fileset')
      {
        $fs= new AIX::Software::Fileset;
        ## print ">>>>>>> NEW FILESET\n";

        push (@{$cat->{'filesets'}}, $fs);

	$usr_files= $fs->{'usr_files'};
	$usr_catalog= $fs->{'usr_catalog'};
      }

      next;
    }
    elsif ($_ eq 'EOUSRFiles_catalog')
    {
      $section= 'Fileset';
      next;
    }
    elsif ($_ eq 'EOFileset')
    {
      $section= 'Package';
      next;
    }

    if ($section eq 'Package')
    {
      ## print ">> $section: '$_'\n";
      if ($_ =~ /^([\w\s]+):\s*(.+)/)
      {
	my ($an, $av)= ($1, $2);
	$pkg->set ($an => $av);
      }
    }
    elsif ($section eq 'Fileset')
    {
      ## print ">> $section: '$_'\n";
      if ($_ =~ /^([\w\s]+):\s*(.+)/)
      {
	my ($an, $av)= ($1, $2);
        $fs->set ($an => $av);
      }
    }
    elsif ($section eq 'USRFiles')
    {
      push (@$usr_files, $_);
    }
    elsif ($section eq 'USRFiles_catalog')
    {
      my ($md5, $x_file, $size, $filename)= split (' ', $_, 4);
      ## print ">> catalog: '$filename'\n";
      push (@$usr_files, $filename);
      $usr_catalog->{$filename}= [ $md5, $size ];
    }
    else
    {
      print ">>>>> unknown section '$section': '$_'\n";
    }
  }
  close (FI);
}

sub print_template
{
  my $cat= shift;

  my ($pkg, $filesets)= $cat->get ('pkg', 'filesets');
  my ($fnm)= $pkg->get ('template');

  local *FO;
  open (FO, '>' . $fnm) or die;
  foreach my $kw (@Package_Fields)
  {
    my ($v)= $pkg->get ($kw);
    print FO "$kw: $v\n";
  }

  foreach my $fs (@$filesets)
  {
    $fs->print_template (*FO);
  }

  close (FO);
}

1;

