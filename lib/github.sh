#!/usr/bin/env bash
# lib/github.sh — fonctions GitHub + init local

: "${GITHUB_USER:?Variable GITHUB_USER non définie}"
: "${GITHUB_TOKEN:?Variable GITHUB_TOKEN non définie}"
: "${GIT_USER_NAME:=$GITHUB_USER}"
: "${GIT_USER_EMAIL:=?Variable GIT_USER_EMAIL non définie}"

API_URL="https://api.github.com"
GRAPHQL_API_URL="https://api.github.com/graphql"

init_remote_repo() {
  local repo_name="$1" private="${2:-false}" path="${3:-.}"
  echo "📁 Création du repo GitHub '$repo_name' (privé:$private)…"
  status=$(curl -s -o /tmp/gh.json -w "%{http_code}" \
    -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -X POST "$API_URL/user/repos" \
    -d "{\"name\":\"$repo_name\",\"private\":$private}")
  [[ "$status" == "201" ]] && echo "✅ Créé." || echo "⚠️ Déjà existant ou erreur ($status)."
  # config Git user
  git config --global user.name  "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  # init local
  mkdir -p "$path"; cd "$path" || return 1
  git init; echo "# $repo_name" > README.md; echo "node_modules/" > .gitignore
  git add .; git commit -m "Initial commit"; git branch -M main
  git remote add origin "https://github.com/$GITHUB_USER/$repo_name.git"
  git push -u origin main
  echo "✅ Local initialisé et poussé."
}

create_github_repo()         { init_remote_repo "$@"; }
create_board() {
  local repo="$1"
  echo "🔧 Création board pour $repo…"
  user_id=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL" \
    -H "Content-Type: application/json" -d '{"query":"query{viewer{id}}"}' \
    | jq -r '.data.viewer.id')
  project_id=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"mutation{createProjectV2(input:{ownerId:\\\"$user_id\\\",title:\\\"Board $repo\\\"}){projectV2{id}}}\"}" \
    | jq -r '.data.createProjectV2.projectV2.id')
  for col in "To Do" "In Progress" "Done"; do
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL/projects/columns?project_id=$project_id" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$col\"}" >/dev/null
  done
  echo "✅ Board créé."
}
create_issues() {
  local repo="$1"
  declare -A issues=(
    ["Config Init"]="Configurer l'environnement."
    ["Doc"]="Rédiger la doc."
    ["Tests"]="Écrire les tests."
  )
  for title in "${!issues[@]}"; do
    resp=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
      -H "Accept:application/vnd.github+json" \
      -X POST "$API_URL/repos/$GITHUB_USER/$repo/issues" \
      -d "{\"title\":\"$title\",\"body\":\"${issues[$title]}\"}")
    echo "✅ Issue: $(echo "$resp" | jq -r '.html_url')"
  done
}
setup_board_and_issues() { create_board "$1"; create_issues "$1"; }
create_github_issue()    { curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -H "Accept:application/vnd.github+json" \
    -X POST "$API_URL/repos/$GITHUB_USER/$2/issues" \
    -d "{\"title\":\"$1\"}" \
  | jq -r '.html_url' \
  | xargs -I{} echo "✅ Issue créée: {}"
}
assign_github_issue() { local num="$1"; local user="$2"; local repo="${3:-$1}"
  curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -X POST "$API_URL/repos/$GITHUB_USER/$repo/issues/$num/assignees" \
    -H "Accept:application/vnd.github+json" \
    -d "{\"assignees\":[\"$user\"]}" \
  && echo "✅ $user assigné à #$num"
}