#!/usr/bin/env bash

echo "hook:configure:triggered"

# Test command
waitFor --command "sleep 1 && echo 'waitFor:command:succeeded'" --timeout 5

# Test tcp port
waitFor --host www.google.com --port 443 --timeout 1
