#!/usr/bin/perl

=head1 NAME

  pmlnk -- Perl Module Link

=cut

use strict;

package pmlnk;

use Data::Dumper;
$Data::Dumper::Indent= 1;

__PACKAGE__->main() unless caller();

sub main
{
  # print __LINE__, " caller: ", join(' ', caller()), "\n";

  my @dirs= ();
  my $target;
  while (my $arg= shift (@ARGV))
  {
    # print __LINE__, " arg=[$arg]\n";

       if ($arg eq '--') { push (@dirs, @ARGV); @ARGV= (); }
    elsif ($arg =~ /^--(.+)/)
    {
      my ($opt, $val)= split ('=', $1, 2);
      if ($opt eq 'help') { usage(); }
      elsif ($opt eq 'target') { $target= shift(@ARGV); }
      else { usage(); }
    }
    elsif ($arg =~ /^-(.+)/)
    {
      foreach my $opt (split ('', $1))
      {
           if ($opt eq 'h') { usage(); exit (0); }
      # elsif ($opt eq 'x') { $x_flag= 1; }
        else { usage(); }
      }
    }
    else
    {
      push (@dirs, $arg);
    }
  }

  push (@dirs, '.') unless (@dirs);

  my $pmlnk= pmlnk->new();

  # print __LINE__, " dirs: ", join(' ', @dirs), "\n";
  foreach my $dir (@dirs)
  {
    # print __LINE__, " dir=[$dir]\n";
    my $pm_files= $pmlnk->find_modules($dir, 'pm');
    # print __LINE__, " pm_files: ", join(' ', @$pm_files), "\n";
    $pmlnk->check_module_list(@$pm_files);
  }

  if (defined ($target))
  {
    $pmlnk->make_links($target)
  }
  else
  {
    print __LINE__, " pmlnk: ", Dumper($pmlnk);
  }
}

sub usage
{
  system ($0);
}

sub new
{
  my $class= shift;
  my $self=
  {
    files => [],
    modules => [],
  };
  bless $self, $class;
}

sub find_modules
{
  my $self= shift;
  my $path= shift || '.';
  my $extension= shift || 'pm';

  my @dirs= ($path);
  my $files= $self->{files};
  my @new_files= ();
  DIR: while (my $dir= shift (@dirs))
  {
    opendir(DIR, $dir) or die;
    # print __LINE__, " reading dir [$dir]\n";

    ENTRY: while (my $e= readdir(DIR))
    {
      next ENTRY if ($e eq '.' || $e eq '..');
      next ENTRY if ($e eq '.git' || $e eq '.svn' || $e eq 'CVS');

      my $fp= join('/', $dir, $e);
      # print __LINE__, " e=[$e] fp=[$fp]\n";
      # my @st= stat($fp);
      if (-d $fp)
      {
        push(@dirs, $fp);
      }
      elsif (-f $fp)
      {
        my @e= split(/\./, $e);
        my $ext= pop (@e);
        # print __LINE__, " e=[$e] ext=[$ext]\n";
        if ($ext eq $extension)
        {
          push (@$files, $fp);
          push (@new_files, $fp);
        }
      }
    }
    closedir(DIR);
  }

  (wantarray) ? @new_files : \@new_files;
}

sub check_module_list
{
  my $self= shift;
  my @pm_files= @_;

  my $modules= $self->{modules};
  foreach my $pm_file (@pm_files)
  {
    my $info= $self->check_module ($pm_file);
    # print __LINE__, " pm_file=[$pm_file] info: ", Dumper($info);
    push (@$modules, $info);
  }
}

sub check_module
{
  my $self= shift;
  my $fnm= shift;

  open (F, '<:utf8', $fnm) or die;
  my @packages= ();
  my @uses= ();
  while (<F>)
  {
    chop;
    push (@packages, $1) if (m#^\s*package\s*([\w\d:_]+)[\(\); ]#);
    push (@uses, $1) if (m#^\s*use\s*([\w\d:_]+)[\(\); ]#);
  }
  close (F);

  my $info=
  {
    filename => $fnm,
    packages => \@packages,
    uses => \@uses,
  };

  # find out, which package name matches filename
  my @fnm= reverse split(/\//, $fnm);
  foreach my $pkg (@packages)
  {
    next if ($pkg eq 'strict' || $pkg eq 'warnings');
    my @pkg= reverse split('::', $pkg);
    $pkg[0] .= '.pm';
    # print __LINE__, " pkg=[$pkg] pkg-list: ", join(' ', @pkg), "\n";
    my $match= 1;
    M: for (my $i= 0; $i <= $#pkg; $i++) { if ($pkg[$i] ne $fnm[$i]) { $match= 0; last M; } }
    if ($match)
    {
      # print __LINE__, " match: $fnm == $pkg\n";
      $info->{matching_package_name}= $pkg;
    }
  }

  $info;
}

sub make_links # or maybe copy the file?
{
  my $self= shift;
  my $target= shift;

  mk_dir($target);

  my $modules= $self->{modules};
  MODULE: foreach my $module (@$modules)
  {
    # print __LINE__, " module: ", Dumper($module);
    my $pkg_name= $module->{matching_package_name};
    unless ($pkg_name)
    {
      print "ATTN: no matching_package_name detected!\n";
      print __LINE__, " module: ", Dumper($module);
      next MODULE;
    }

    my @pkg_name= split('::', $pkg_name);
    my $module_name= pop(@pkg_name);
    my $t_path= $target;

    while (my $t_dir= shift (@pkg_name))
    {
      $t_path .= '/'. $t_dir;
      mk_dir($t_path);
    }
    $t_path .= '/'. $module_name . '.pm';
    mk_link($module->{filename}, $t_path);
  }
}

=head1 Internal Functions

=head2 mkdir($path)

=cut

sub mk_dir
{
  my $path= shift;
  unless (-d $path)
  {
    print "creating $path\n";
    mkdir($path);
  }
}

sub mk_link
{
  my $old= shift;
  my $new= shift;

  if (-l $new)
  {
    # print "symlink [$new] already exists, ignoring\n";
  }
  elsif (-f $new)
  {
    print "ATTN: symlink [$new] already exists as file!\n";
  }
  else
  {
    print "symlinking $new -> $old\n";
    symlink($old, $new);
  }
}

