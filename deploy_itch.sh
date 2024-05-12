#!/bin/bash

version=$1

if [[ $version == "" || !($version =~ ".") ]]; then
    echo "Invalid version, received: "$1
    exit 1
fi

echo "Deploying version $version (win) build to itch..."
butler push ./dist/windows_amd64_release colinbellino/chess:win --userversion=$version
butler push ./dist/Chess.app colinbellino/chess:mac --userversion=$version
