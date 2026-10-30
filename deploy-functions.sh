#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
project_id="snail-mail-btc"

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  print -u2 "nvm is required. Install Node 22, then retry."
  exit 1
fi

source "$HOME/.nvm/nvm.sh"
nvm use 22 >/dev/null

if [[ "$(node --version)" != v22.* ]]; then
  print -u2 "Node 22 is required to analyze and deploy this Functions codebase."
  exit 1
fi

cd "$project_dir"
print "Checking the reviewed backend…"
npm --prefix firebase/functions run check
npm --prefix firebase/functions run build

print "Deploying only Functions to $project_id…"
npx -y firebase-tools@latest deploy \
  --only functions \
  --project "$project_id" \
  --non-interactive

print "Keeping only one day of stale deployment images…"
npx -y firebase-tools@latest functions:artifacts:setpolicy \
  --project "$project_id" \
  --location us-east1 \
  --days 1 \
  --force

print "Snail Mail Functions are deployed with artifact cleanup enabled."
