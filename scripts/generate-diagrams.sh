#!/bin/bash
set -e

mkdir -p docs/diagrams

echo "Generating storage diagram..."
sol2uml storage contracts -c NoxComputeStorageStub -o docs/diagrams/storage.svg

echo "Generating class diagram..."
sol2uml class contracts -b NoxCompute --hideFilename --hideLibraries --hideModifiers --hideEnums --hideStructs -o docs/diagrams/class.svg
