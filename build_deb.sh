#!/bin/sh

echo 'increment the version number, when necessary!'
epoch=0
version=0.1-2
pkgdir=tmp/stage/libgg-aix-pm-perl/$epoch/$version

scripts/pmlnk.pm --copy --target $pkgdir/data/usr/share/perl5 .
mkdir $pkgdir/control
cp debian/control $pkgdir/control
cp debian/debian-binary $pkgdir
scripts/mkdeb.pl $pkgdir
