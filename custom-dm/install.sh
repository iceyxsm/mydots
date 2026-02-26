#!/bin/bash
# Custom Display Manager Installer - Delegates to main installer
echo "Use install-custom-dm.sh in the parent directory instead."
echo "Running: sudo ./install-custom-dm.sh"
sudo "$(dirname "$0")/../install-custom-dm.sh"
