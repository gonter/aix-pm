#!/bin/sh

epoch=0
version=`awk '/^Version:/ {print $2}' debian/scripts/control`
pkgname=`awk '/^Package:/ {print $2}' debian/scripts/control`
pkgdir=tmp/stage/$pkgname/$epoch/$version

bindir=$pkgdir/data/usr/bin
mkdir -p $pkgdir/control

cp debian/scripts/control $pkgdir/control
echo "2.0" >$pkgdir/debian-binary

mkdir -p $bindir
cp scripts/mkdeb.pl $bindir/
cp hacks/linux/lvm/chfs.pl $bindir/
cp hacks/linux/lvm/cfgmgr.pl $bindir/
cp modules/util/csv.pl $bindir/
ln -s ../share/perl5/Net/fanout.pm $bindir/fanout
ln -s ../share/perl5/pmlnk.pm $bindri/pmlnk

echo scripts/mkdeb.pl $pkgdir $*
scripts/mkdeb.pl --gz $pkgdir $*

