
#!/bin/bash

version=$1

docker build --pull --build-arg server_version=$version -t tengis/tengis-wiki:${version}-testing ./



docker push tengis/tengis-wiki:${version}-testing



echo tengis/tengis-wiki:${version}-testing
