#!/bin/bash

version=$1
first_num=$(echo $version | cut -d '.' -f1)
second_num=$(echo $version | cut -d '.' -f2)

docker manifest rm tengis/tengis-wiki:${first_num}.${second_num}-latest

docker manifest create tengis/tengis-wiki:${first_num}.${second_num}-latest tengis/tengis-wiki:${version}-testing tengis/tengis-wiki:${version}-arm-testing

docker manifest push tengis/tengis-wiki:${first_num}.${second_num}-latest



docker manifest rm tengis/tengis-wiki:${version}

docker manifest create tengis/tengis-wiki:${version} tengis/tengis-wiki:${version}-testing tengis/tengis-wiki:${version}-arm-testing

docker manifest push tengis/tengis-wiki:${version}



echo tengis/tengis-wiki:${first_num}.${second_num}-latest
echo tengis/tengis-wiki:${version}
