#!/bin/bash

diff --minimal \
     --brief \
     --ignore-all-space \
     --recursive \
     --exclude=".git" \
     --exclude="pkg" \
     --exclude="tmp" \
     --exclude="README.md" \
     --exclude="NEWS.md" \
     --exclude="USAGE" \
     --exclude="LICENSE" \
     --exclude="Gemfile.lock" \
     ./ ../suspenders
