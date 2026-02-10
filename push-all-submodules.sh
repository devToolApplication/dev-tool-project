#!/bin/bash
set -e

echo "🚀 Push all changed submodules..."

# Lấy danh sách submodule
git submodule foreach '
  echo "📦 Checking $name..."

  if [ -n "$(git status --porcelain)" ]; then
    echo "➡️  Changes detected in $name"

    git add .
    git commit -m "Auto commit from super project"
    git push
  else
    echo "✅ No changes in $name"
  fi
'

echo "📌 Updating super project..."

git add .
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "Update submodule references"
  git push
else
  echo "✅ No changes in super project"
fi

echo "🎉 Done!"
