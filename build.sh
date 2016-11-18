#!/bin/sh

xcodebuild -workspace outlander.xcworkspace \
       -scheme OutlanderTests \
       clean test | xcpretty -tc

if [ $? -eq 0 ]
then
  echo "Build Success"
  exit 0
else
  echo "Build Failed"
  exit 1
fi