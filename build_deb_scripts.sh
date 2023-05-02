#!/bin/sh

epoch=0
version=`awk '/Version:/ {print $2}' scripts/debian/control`
pkgname=`awk '/Package:/ {print $2}' scripts/debian/control`
pkgdir=tmp/stage/$pkgname/$epoch/$version

bindir=$pkgdir/data/usr/bin
mkdir -p $pkgdir/control

cp scripts/debian/control $pkgdir/control
cp debian/debian-binary $pkgdir

mkdir -p $bindir
cp scripts/mkdeb.pl $bindir/
cp modules/util/csv.pl $bindir/

scripts/mkdeb.pl $pkgdir
