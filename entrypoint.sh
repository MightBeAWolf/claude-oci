#!/bin/bash
set -e

# Activate mise environment
eval "$(mise activate bash)"

# Execute claude with all arguments, replacing this process
exec claude "$@"
