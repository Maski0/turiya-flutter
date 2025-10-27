#!/bin/bash

echo "🔨 Regenerating Isar schemas..."
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -eq 0 ]; then
  echo "✅ Build completed successfully!"
else
  echo "❌ Build failed!"
  exit 1
fi

