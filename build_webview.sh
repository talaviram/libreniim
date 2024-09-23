#!/bin/bash
echo "Building webview..."
cd ./web/labeleditor || { echo "Failed to navigate to webview"; exit 1; }
npm run build || { echo "Build failed"; exit 1; }
cd ../../
if [ -d "./apple/LibreNiim.swiftpm/Resources/webview" ]; then
  echo "Clearing ./app/Resources/webview..."
  rm -rf ./apple/LibreNiim.swiftpm/Resources/webview/*
else
  echo "Resources/webview does not exist, creating it..."
  mkdir -p ./apple/LibreNiim.swiftpm/Resources/webview
fi
echo "Copying newly built content to ./apple/LibreNiim.swiftpm/Resources/webview..."
cp -r ./web/labeleditor/dist/* ./apple/LibreNiim.swiftpm/Resources/webview/

echo "Build and copy completed successfully."