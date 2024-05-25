#!/bin/bash

version=$1

if [[ $version == "" || !($version =~ ".") ]]; then
    echo "Invalid version, received: "$1
    exit 1
fi

echo "Deploying version $version (win) build to itch..."
butler push ./dist/WINDOWS_X64_RELEASE/ colinbellino/chess:win --userversion=$version
butler push ./Chess.app colinbellino/chess:mac --userversion=$version
