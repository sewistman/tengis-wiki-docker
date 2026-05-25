
#!/bin/bash

version=$1

docker build --pull --build-arg server_version=$version -t docker.seafile.top/tengis/tengis-wiki:${version}-testing ./

docker tag docker.seafile.top/tengis/tengis-wiki:${version}-testing tengis/tengis-wiki:${version}-testing



docker push tengis/tengis-wiki:${version}-testing

docker push docker.seafile.top/tengis/tengis-wiki:${version}-testing



echo docker.seafile.top/tengis/tengis-wiki:${version}-testing
echo tengis/tengis-wiki:${version}-testing
