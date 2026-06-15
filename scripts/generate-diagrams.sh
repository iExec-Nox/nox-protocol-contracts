#!/bin/bash
set -e

mkdir -p docs

echo "Generating storage diagram..."
sol2uml storage contracts -c NoxComputeStorageStub -o docs/storage.svg

echo "Generating class diagram..."
sol2uml class contracts -b NoxCompute --hideFilename --hideLibraries --hideModifiers -o docs/class.svg
