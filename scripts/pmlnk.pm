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
  my $pkg_list;
  my %par= ( op_mode => 'link' );
  while (my $arg= shift (@ARGV))
  {
    # print __LINE__, " arg=[$arg]\n";

       if ($arg eq '--') { push (@dirs, @ARGV); @ARGV= (); }
    elsif ($arg =~ /^--(.+)/)
    {
      my ($opt, $val)= split ('=', $1, 2);
      if ($opt eq 'help') { usage(); }
      elsif ($opt eq 'copy') { $par{op_mode}= 'copy'; }
      elsif ($opt eq 'force' || $opt eq 'overwrite') { $par{force}= 1; }
      elsif ($opt eq 'link') { $par{op_mode}= 'link'; }
      elsif ($opt eq 'packages') { $pkg_list= shift(@ARGV); }
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

  $par{pkg_list}= read_items($pkg_list) if (defined ($pkg_list));
  my $pmlnk= pmlnk->new( %par );

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
    $pmlnk->make_links_or_copies($target)
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
    @_,
    files => [],
    modules => [],
  };
  bless $self, $class;
  # print __LINE__, " self: ", Dumper($self); exit;
}

sub find_modules
{
  my $self= shift;
  my $path= shift;
  my $extension= shift || 'pm';

  my @dirs= ($path);
  my $files= $self->{files};
  my @new_files= ();
  DIR: while (my $dir= shift (@dirs))
  {
    unless ($dir =~ m#^/#)
    {
      $dir= undef if ($dir eq '.');
      while ($dir=~ s#^\.\/##) {}
      die "don't do that [$dir]" if ($dir eq '..' || $dir =~ m#^\.\.\/#);
      my $pwd= `pwd`;
      chop($pwd);
      $dir= (defined ($dir) && $dir ne '') ? join('/', $pwd, $dir) : $pwd;
    }
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

sub make_links_or_copies
{
  my $self= shift;
  my $target= shift;

  # create target path
  {
    my @target= split('/', $target);
    my @new_target;
    foreach my $t (@target)
    {
      next if ($t eq '.');
      if ($t eq '..')
      { # TODO: maybe we should care for an empty directory in the target
        pop(@new_target);
        next;
      }
      push(@new_target, $t);
      mk_dir(join('/', @new_target));
    }
    $target= join('/', @new_target);
  }

  my $op_mode= ($self->{op_mode} eq 'copy') ? 1 : 0;
  my $force= (exists($self->{force}) && $self->{force}) ? 1 : 0;

  my $check_package_list= 0;
  my %pkg_list;
  if (exists ($self->{pkg_list}))
  {
    my @pkg_list= @{$self->{pkg_list}};
    die " empty package list!" unless (@pkg_list);
    %pkg_list= map { $_ => 1 } @pkg_list;
    $check_package_list= 1;
  }

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

    next if ($check_package_list && !$pkg_list{$pkg_name});

    my @pkg_name= split('::', $pkg_name);
    my $module_name= pop(@pkg_name);
    my $t_path= $target;

    while (my $t_dir= shift (@pkg_name))
    {
      $t_path .= '/'. $t_dir;
      mk_dir($t_path);
    }
    $t_path .= '/'. $module_name . '.pm';

    if ($op_mode)
    {
      mk_copy($module->{filename}, $t_path, $force);
    }
    else
    {
      mk_link($module->{filename}, $t_path, $force);
    }
  }
}

=head1 Internal Functions

=head2 mk_dir($path)

=cut

sub mk_dir
{
  my $path= shift;
  if ($path && !-d $path)
  {
    print "creating [$path]\n";
    mkdir($path);
  }
}

sub mk_link
{
  my $src= shift;
  my $dst= shift;
  my $force= shift;

  if (-l $dst)
  {
    my $lnk= readlink($dst);
    if ($src eq $lnk) { } # ignore, that's the same thing
    else
    {
      print "different symlink already exists\n";
      print "dst=[$dst]\n";
      print "src=[$src]\n";
      print "lnk=[$lnk]\n";
      if ($force)
      {
        unlink($dst);
        goto LINK;
      }
    }
  }
  elsif (-f $dst)
  {
    print "ATTN: symlink [$dst] already exists as file!\n";
    if ($force)
    {
      unlink($dst);
      goto LINK;
    }
  }
  else
  {
LINK:
    print "symlinking $dst -> $src\n";
    symlink($src, $dst);
  }
}

sub mk_copy
{
  my $src= shift;
  my $dst= shift;
  my $force= shift;

  if (-l $dst)
  {
    my $lnk= readlink($dst);
    print "ATTN: exists as symlink:\n";
    print "lnk=[$lnk]\n";
    if ($force)
    {
      unlink ($dst);
      goto COPY;
    }
  }
  elsif (-f $dst)
  {
    print "ATTN: file [$dst] already exists!\n";
    goto COPY if ($force);
  }
  else
  {
COPY:
    print "copying $src to $dst\n";
    copy_file($src, $dst);
  }
}

sub copy_file
{
  my $src= shift;
  my $dst= shift;

  open (FI, '<:raw', $src) or die "can't read source [$src]";
  open (FO, '>:raw', $dst) or die "can't write to destination [$dst]";
  my $buffer;
  while (1)
  {
    my $cnt= sysread(FI, $buffer, 64*1024);
    last unless ($cnt > 0);
    syswrite(FO, $buffer);
  }
  close(FO);
  close(FI);
}

sub read_items
{
  my $fnm= shift;
  open (FI, '<:utf8', $fnm) or die "can't read item list [$fnm]";
  my @list;
  while (<FI>)
  {
    chop;
    next if (m/^#/ || m/^\s*$/);
    push (@list, $_);
  }
  close(FI);
  \@list;
}
