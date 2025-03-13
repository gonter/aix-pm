#!/bin/sh

epoch=0
version=`awk '/Version:/ {print $2}' debian/lib/control`
pkgname=`awk '/Package:/ {print $2}' debian/lib/control`
pkgdir=tmp/stage/$pkgname/$epoch/$version

scripts/pmlnk.pm --copy --target $pkgdir/data/usr/share/perl5 .

chmod +x $pkgdir/data/usr/share/perl5/Net/fanout.pm

mkdir $pkgdir/control
cp debian/lib/control $pkgdir/control
echo "2.0" >$pkgdir/debian-binary

echo scripts/mkdeb.pl $pkgdir $*
scripts/mkdeb.pl --gz $pkgdir $*

