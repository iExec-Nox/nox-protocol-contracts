#!/usr/bin/env sh

set -eu

mkdir -p docs/diagrams

SOL2UML="pnpm dlx sol2uml@2.5.26"

echo "Generating storage diagram..."
$SOL2UML storage contracts -c NoxCompute -o docs/diagrams/storage.svg

echo "Generating class diagram..."
$SOL2UML class contracts -b NoxCompute --hideFilename --hideLibraries --hideModifiers --hideEnums --hideStructs -o docs/diagrams/class.svg
