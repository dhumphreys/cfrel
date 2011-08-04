#!/bin/bash

# remove the existing zip file
rm -f cfrel-0.0.1.zip

# load in the basic plugin files
zip cfrel-0.0.1.zip CFRel.cfc index.cfm

# add the core CFRel files
zip -r cfrel-0.0.1.zip cfrel/cfrel
