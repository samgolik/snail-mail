#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"

if [[ "$node_major" != "22" ]]; then
  print -u2 "Snail Mail's local backend uses Node 22."
  print -u2 "With nvm installed, run: nvm install 22 && nvm use 22"
  exit 1
fi

cd "$project_dir"
npm --prefix firebase/functions run build
CHOKIDAR_USEPOLLING=1 npx -y firebase-tools@latest emulators:start \
  --only auth,firestore,functions \
  --project snail-mail-btc
