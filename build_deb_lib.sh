#!/bin/sh

epoch=0
version=`awk '/Version:/ {print $2}' debian/control`
pkgname=`awk '/Package:/ {print $2}' debian/control`
pkgdir=tmp/stage/$pkgname/$epoch/$version

scripts/pmlnk.pm --copy --target $pkgdir/data/usr/share/perl5 .

chmod +x $pkgdir/data/usr/share/perl5/Net/fanout.pm

mkdir $pkgdir/control
cp debian/control $pkgdir/control
cp debian/debian-binary $pkgdir

echo scripts/mkdeb.pl $pkgdir $*
scripts/mkdeb.pl $pkgdir $*

