#!/bin/bash

# set version
VERSION=0.1.1

# set path to export to
COREZIP=cfrel-core-$VERSION.zip
WHEELSZIP=cfrel-$VERSION.zip

# create and enter build directory
if [ ! -d build ]; then
    mkdir build
fi
cd build

# copy files into this view
cp -dr ../src cfrel
cp -dr ../src lib
cp ../plugins/cfwheels/cfrel.cfc .
cp ../plugins/cfwheels/index.cfm .

# compile the cfwheels zip file
rm -f $WHEELSZIP
zip -r $WHEELSZIP cfrel.cfc index.cfm lib

# compile the core library zip file
rm -f $COREZIP
zip -r $COREZIP cfrel

# remove copied files
rm -dr cfrel lib
rm cfrel.cfc index.cfm