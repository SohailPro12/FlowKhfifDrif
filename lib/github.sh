#!/usr/bin/env bash
# lib/github.sh — fonctions GitHub + init local

# Utilisation du répertoire personnel pour la configuration et les logs
HOME_DIR="${HOME:-/home/$(whoami)}"
CONFIG_FILE="$HOME_DIR/.flowkhfifdrif/config.sh"
LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"

# Charger les variables d'environnement depuis config.sh si le fichier existe
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log_message "WARN" "Fichier de configuration non trouvé : $CONFIG_FILE"
fi
# Vérifie que les variables GitHub sont bien définies ou utilise une valeur par défaut
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GIT_USER_NAME="${GIT_USER_NAME:-$GITHUB_USER}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  source "$HOME_DIR/.flowkhfifdrif/lib/logger.sh"
fi

# Fonction pour vérifier les variables d'environnement avant d'exécuter des commandes GitHub
check_github_env() {
  if [[ -z "$GITHUB_USER" || -z "$GITHUB_TOKEN" || -z "$GIT_USER_EMAIL" ]]; then
    log_message "ERROR" "Variables d'environnement GitHub manquantes. Définissez GITHUB_USER, GITHUB_TOKEN et GIT_USER_EMAIL." 104
    return 1
  fi
  return 0
}

# Définition des URLs de l'API GitHub
API_URL="https://api.github.com"
GRAPHQL_API_URL="https://api.github.com/graphql"

# Utilisation du répertoire personnel de l'utilisateur pour les logs
if [[ -z "$LOG_DIR" ]]; then
  HOME_DIR="${HOME:-/home/$(whoami)}"
  LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
fi

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  source "$LOG_DIR/../lib/logger.sh"
fi

# Fonction d'initialisation d'un dépôt distant et local
init_remote_repo() {
  local repo_name="$1"
  local private="${2:-false}"
  local path="${3:-.}"

  if ! check_github_env; then
    return 1
  fi

  log_message "INFO" "Création du repo GitHub '$repo_name' (privé:$private)…"

  local status=$(curl -s -o /tmp/gh.json -w "%{http_code}" \
    -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -X POST "$API_URL/user/repos" \
    -d "{\"name\":\"$repo_name\",\"private\":$private}")

  if [[ "$status" == "201" ]]; then
    log_message "INFO" "Dépôt GitHub créé avec succès."
  else
    log_message "WARN" "Dépôt déjà existant ou erreur ($status)."
  fi

  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"

  mkdir -p "$path" || { log_message "ERROR" "Impossible de créer le répertoire $path" 102; return 1; }
  cd "$path" || { log_message "ERROR" "Impossible d'accéder au répertoire $path" 102; return 1; }

  local actual_path
  actual_path="$(pwd -P)"

  git init
  echo "# $repo_name" > README.md
  echo "node_modules/" > .gitignore
  git add .
  git commit -m "Initial commit"
  git branch -M main
  git remote add origin "https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$repo_name.git"
  git push -u origin main

  if [[ $? -ne 0 ]]; then
    log_message "ERROR" "Échec du push vers GitHub. Veuillez vérifier vos identifiants." 104
    return 1
  fi

  log_message "INFO" "Dépôt local initialisé et poussé vers GitHub."

  # Sauvegarde du chemin et du nom du dépôt
  local config_file="$HOME/.flowkhfifdrif/config.sh"
  mkdir -p "$(dirname "$config_file")"

  # Nettoyage des anciennes variables si elles existent
  if [[ -f "$config_file" ]]; then
    sed -i '/FLOW_LAST_REPO_PATH/d' "$config_file"
    sed -i '/FLOW_LAST_REPO_NAME/d' "$config_file"
  fi

  # Ajout des nouvelles variables
  {
    echo "export FLOW_LAST_REPO_PATH=\"$actual_path\""
    echo "export FLOW_LAST_REPO_NAME=\"$repo_name\""
  } >> "$config_file"

  return 0
}



create_github_repo() {
  if ! check_github_env; then
    return 1
  fi
  init_remote_repo "$@"
  return $?
}

create_board() {
  local repo_name="$1"

  if ! check_github_env; then
    return 1
  fi

  log_message "INFO" "Création du tableau de bord pour '$repo_name'..."

  user_id_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL" \
    -H "Content-Type: application/json" \
    -d '{"query":"query { viewer { id } }"}')

  user_id=$(echo "$user_id_response" | jq -r '.data.viewer.id')

  if [ "$user_id" == "null" ] || [ -z "$user_id" ]; then
    log_message "ERROR" "Impossible d'obtenir l'ID utilisateur. Réponse: $user_id_response" 103
    return 1
  fi

  project_mutation=$(cat <<EOF
mutation {
  createProjectV2(input: {ownerId: "$user_id", title: "Tableau de bord $repo_name"}) {
    projectV2 {
      id
      url
    }
  }
}
EOF
)

  project_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$(echo "$project_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}")

  project_id=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.id')
  project_url=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.url')

  if [ "$project_id" == "null" ] || [ -z "$project_id" ]; then
    log_message "ERROR" "Erreur de création du tableau. Réponse: $project_response" 103
    return 1
  fi

  log_message "INFO" "Project V2 créé: $project_url"

  create_field_mutation=$(cat <<EOF
mutation {
  createProjectV2Field(input: {
    projectId: "$project_id",
    name: "État",
    dataType: SINGLE_SELECT,
    singleSelectOptions: [
      {name: "À faire", color: BLUE, description: "Tâches à démarrer"},
      {name: "En cours", color: ORANGE, description: "Tâches en cours de réalisation"},
      {name: "Terminé", color: GREEN, description: "Tâches complétées et validées"}
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        options {
          id
          name
        }
      }
    }
  }
}
EOF
)

  field_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X POST "$GRAPHQL_API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$(echo "$create_field_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}")

  if echo "$field_response" | jq -e '.errors' > /dev/null; then
    log_message "ERROR" "Erreur création du champ 'État'. Réponse: $field_response" 103
    return 1
  fi

  log_message "INFO" "Champ 'État' ajouté au projet."
  return 0
}

assign_github_issue() {
  local issue_number="$1"
  local assignee="$2"
  local repo_name="$3"

  if ! check_github_env; then
    return 1
  fi

  log_message "INFO" "Attribution de l'utilisateur '$assignee' à l'issue #$issue_number dans '$repo_name'..."

  repo_exists=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$GITHUB_USER:$GITHUB_TOKEN" \
    "$API_URL/repos/$GITHUB_USER/$repo_name")

  if [ "$repo_exists" != "200" ]; then
    log_message "ERROR" "Le dépôt '$repo_name' n'existe pas ou n'est pas accessible." 104
    return 1
  fi

  response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -X PATCH "$API_URL/repos/$GITHUB_USER/$repo_name/issues/$issue_number" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"assignees\": [\"$assignee\"]}")

  if echo "$response" | jq -e '.assignees' > /dev/null; then
    log_message "INFO" "Utilisateur '$assignee' assigné à l'issue #$issue_number."
    return 0
  else
    log_message "ERROR" "Échec de l'assignation. Réponse : $response" 104
    return 1
  fi
}

create_github_issue() {
  local title="$1"
  local repo_name="$2"
  local body="${3:-"Issue créée automatiquement."}"

  if ! check_github_env; then
    return 1
  fi

  log_message "INFO" "Vérification de l'existence du dépôt '$repo_name'..."

  repo_exists=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$GITHUB_USER:$GITHUB_TOKEN" \
    "$API_URL/repos/$GITHUB_USER/$repo_name")

  if [ "$repo_exists" != "200" ]; then
    log_message "ERROR" "Le dépôt '$repo_name' n'existe pas ou vous n'y avez pas accès." 104
    return 1
  fi

  log_message "INFO" "Création issue \"$title\" dans '$repo_name'..."

  response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
    -X POST "$API_URL/repos/$GITHUB_USER/$repo_name/issues" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"title\":\"$title\",\"body\":\"$body\"}")

  issue_url=$(echo "$response" | jq -r '.html_url')
  if [ "$issue_url" != "null" ]; then
    log_message "INFO" "Issue créée: $issue_url"
    return 0
  else
    log_message "ERROR" "Erreur lors de la création de l'issue '$title'. Réponse: $response" 104
    return 1
  fi
}

# Exporter les fonctions
export -f check_github_env
export -f init_remote_repo
export -f create_github_repo
export -f create_board
export -f assign_github_issue
export -f create_github_issue
