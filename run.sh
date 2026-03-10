#!/bin/bash
set -e

./build.sh

echo "Launching Drawer.app..."
open Drawer.app
