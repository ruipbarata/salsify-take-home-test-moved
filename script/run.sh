#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Error: Specify the file"
  exit 1
fi

export FILE_PATH="$1"

if ! pgrep -x "redis-server" > /dev/null; then
    echo "Starting redis server..."
    redis-server --daemonize yes
fi

echo redis-cli ping

bundle install

rails server -b 0.0.0.0 -p 3000
