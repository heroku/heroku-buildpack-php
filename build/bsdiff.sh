#!/bin/bash

cd /tmp
curl -O curl -O http://www.daemonology.net/bsdiff/bsdiff-4.3.tar.gz
tar -xzf bsdiff-4.3.tar.gz
cd bsdiff-4.3
sed -i '13 s/^/#/' Makefile 
sed -i '14 s/^/#/' Makefile 
sed -i '15 s/^/#/' Makefile 
make
mkdir -p /tmp/build/local/bin
cp bsdiff /tmp/build/local/bin
cp bspatch /tmp/build/local/bin
