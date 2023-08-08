#!/bin/sh

epoch=0
version=`awk '/^Version:/ {print $2}' scripts/debian/control`
pkgname=`awk '/^Package:/ {print $2}' scripts/debian/control`
pkgdir=tmp/stage/$pkgname/$epoch/$version

bindir=$pkgdir/data/usr/bin
mkdir -p $pkgdir/control

cp scripts/debian/control $pkgdir/control
cp debian/debian-binary $pkgdir

mkdir -p $bindir
cp scripts/mkdeb.pl $bindir/
cp modules/util/csv.pl $bindir/
ln -s ../share/perl5/Net/fanout.pm $bindir/fanout

echo scripts/mkdeb.pl $pkgdir $*
scripts/mkdeb.pl $pkgdir $*

