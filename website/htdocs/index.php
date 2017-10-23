<?php
// Default Web Page for groups that haven't setup their page yet
// Please replace this file with your own website
//
// $Id: index.php,v 1.6 2012/08/28 12:55:47 baumannba Exp $
//

$headers = getallheaders();
?>
<HTML>
<HEAD>
<TITLE>SourceForge: Welcome</TITLE>
<LINK rel="stylesheet" href="http://sourceforge.net/sourceforge.css" type="text/css">
</HEAD>

<BODY bgcolor=#FFFFFF topmargin="0" bottommargin="0" leftmargin="0" rightmargin="0" marginheight="0" marginwidth="0">

<!-- top strip -->
<TABLE width="100%" border=0 cellspacing=0 cellpadding=2 bgcolor="737b9c">
  <TR>
    <TD><SPAN class=maintitlebar>&nbsp;&nbsp;
      <A class=maintitlebar href="http://sourceforge.net/"><B>Home</B></A> | 
    </TD>
  </TR>
</TABLE>
<!-- end top strip -->

<!-- top title table -->
<TABLE width="100%" border=0 cellspacing=0 cellpadding=0 bgcolor="" valign="center">
  <TR valign="top" bgcolor="#eeeef8">
    <TD>
      <A href="http://sourceforge.net/"><IMG src="http://sourceforge.net/images/sflogo2-steel.png" vspace="0" border=0 width="215" height="105"></A>
    </TD>
    <TD width="99%"><!-- right of logo -->
      <a href="http://www.valinux.com"><IMG src="http://sourceforge.net/images/va-btn-small-light.png" align="right" alt="VA Linux Systems" hspace="5" vspace="7" border=0 width="136" height="40"></A>
    </TD><!-- right of logo -->
  </TR>
  <TR><TD bgcolor="#543a48" colspan=2><IMG src="http://sourceforge.net/images/blank.gif" height=2 vspace=0></TD></TR>
</TABLE>
<!-- end top title table -->

<!-- center table -->
<H1>Welcome to http://<?php print $headers[Host]; ?>/</H1>

<p>For details, see the
<a href="http://sourceforge.net/projects/aix-pm">project page</a>.
There are no file releases yet, all the code is located in the
<a href="http://aix-pm.cvs.sourceforge.net/aix-pm/">CVS tree</a>.
Feature requests and bug reports are welcome, they can easyly be submitted via the
<a href="http://sourceforge.net/tracker/?group_id=1790&atid=351790">tracker</a>.
</p>

<h2>Purpose</h2>
<p>
The initial reason to create this project was to provide a space to
collect AIX specific Perl modules, hence the project name "aix-pm".  These
modules may be specific for AIX, they are however not necessarily limited
to that environment.  Especially those modules which deal with aspects
of SAN managment may be of interest even outside an AIX environment.
</p>

<p>Current work focus:

<ul>
<li>AIX modules for nim, odm, lvm and lpp handling.
<li>SAN administration support:
  <ul>
  <li>EMC CLARiiON monitoring, configuration documentation and statistics
  <li>Brocade configuration documentation
  </ul>
</ul>


<h2>other AIX related projects</h2>
<ul>
<li><a href="http://sourceforge.net/projects/aixtoolbox">AIX Toolbox</a>: IBM's collection of open source or freeware software.
Unfortunately, update cycles are rather long and the collection contains mostly basic stuff.
<li><a href="http://sourceforge.net/projects/aixfreeware/">AIX Freeware</a>: Frank Fegert's collection of open source software.
<li><a href="http://sourceforge.net/porjects/aix-ports/">AIX Ports</a>: new project, still in planning phase
<li><a href="http://www.aixadm.org">AIX adm.org</a>: home of the <a href="http://aixadm.org/mailman/listinfo/cpan">CPAN AIX Perl module discussion list</a>.  Home of <a href="http://search.cpan.org/~critter/AIX-LPP-0.5/LPP/lpp_name.pm">AIX::LPP::lpp_name</a>. Site/list seem to be only partially functional at this time.
<li><a href="http://search.cpan.org/~dfrench/AIX-ODM-1.0.2/ODM.pm">AIX::ODM</a>: IMO a misleading name since this module works with the lsdev command (which uses ODM files).  It does not actually process ODM files and can't be used for stuff such as NIM or SMIT menus.
<p>

</p>
</ul>

<!-- footer table -->
<TABLE width="100%" border="0" cellspacing="0" cellpadding="2" bgcolor="737b9c">
  <TR>
    <TD align="center"><FONT color="#ffffff"><SPAN class="titlebar">
      All trademarks and copyrights on this page are properties of their respective owners. Forum comments are owned by the poster. The rest is copyright ©1999-2000 VA Linux Systems, Inc.</SPAN></FONT>
    </TD>
  </TR>
</TABLE>

<!-- end footer table -->
</BODY>
</HTML>
