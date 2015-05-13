#!/bin/sh

# Fast fail the script on failures.
set -e

# Verify SDK installed and display version
dart --version

# Analyze the code
pub global activate tuneup
pub global run tuneup check
