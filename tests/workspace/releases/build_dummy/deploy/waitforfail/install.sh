#!/usr/bin/env bash

echo "hook:configure:triggered"

waitFor --command "/usr/local/nonexisting" --timeout 1
