#!/bin/bash

# ------------------ CONFIG ------------------ #
: "${GITHUB_USER:?Variable GITHUB_USER non définie}"
: "${GITHUB_TOKEN:?Variable GITHUB_TOKEN non définie}"
API_URL="https://api.github.com"
GRAPHQL_API_URL="https://api.github.com/graphql"
# ------------------------------------------- #

# Vérifier les dépendances
for cmd in git jq; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
  fi
done

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTION] [ARGUMENTS]"
    echo ""
    echo "Options:"
    echo "  -init nom_repo [true|false] [chemin]     Initialise un dépôt Git"
    echo "  -board nom_repo                          Crée un tableau de bord Project V2"
    echo "  -issues nom_repo                         Crée des issues standard"
    exit 1
}

# Fonction création du tableau Project V2
create_board() {
    local repo_name="$1"
    echo "🔧 Création du tableau de bord pour '$repo_name'..."

    # Récupérer l'ID utilisateur
    user_id_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST "$GRAPHQL_API_URL" \
        -H "Content-Type: application/json" \
        -d '{"query":"query { viewer { id } }"}')

    user_id=$(echo "$user_id_response" | jq -r '.data.viewer.id')

    if [ "$user_id" == "null" ] || [ -z "$user_id" ]; then
        echo "❌ Erreur: Impossible d'obtenir l'ID utilisateur. Réponse: $user_id_response"
        return 1
    fi

    # Créer le Project V2
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
    project_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
      -X POST "$GRAPHQL_API_URL" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$(echo "$project_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}")

    project_id=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.id')
    project_url=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.url')

    if [ "$project_id" == "null" ] || [ -z "$project_id" ]; then
        echo "❌ Erreur de création du tableau. Réponse: $project_response"
        return 1
    fi

    echo "✅ Project V2 créé: $project_url"

    # Ajouter un champ personnalisé "État"
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
    field_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
      -X POST "$GRAPHQL_API_URL" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$(echo "$create_field_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}")

    if echo "$field_response" | jq -e '.errors' > /dev/null; then
        echo "❌ Erreur création du champ 'État'. Réponse: $field_response"
        return 1
    fi

    echo "✅ Champ 'État' ajouté au projet."
}

# Fonction création d'issues
create_issues() {
    local repo_name="$1"
    echo "📝 Création des issues dans '$repo_name'..."

    declare -A issues=(
        ["Configuration initiale"]="Configurer l'environnement de développement."
        ["Documentation"]="Rédiger la documentation du projet."
        ["Tests"]="Mettre en place les tests unitaires."
    )

    for title in "${!issues[@]}"; do
        body="${issues[$title]}"
        response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
          -X POST "$API_URL/repos/$GITHUB_USER/$repo_name/issues" \
          -H "Accept: application/vnd.github+json" \
          -d "{\"title\":\"$title\",\"body\":\"$body\"}")

        issue_url=$(echo "$response" | jq -r '.html_url')
        if [ "$issue_url" != "null" ]; then
            echo "✅ Issue créée: $issue_url"
        else
            echo "❌ Erreur création issue '$title'. Réponse: $response"
        fi
    done
}

# Fonction initialisation dépôt Git
init_repo() {
    local repo_name="$1"
    local private="${2:-false}"
    local path="${3:-.}"

    mkdir -p "$path"
    cd "$path" || exit 1

    if [ -d ".git" ]; then
        echo "⚠️ Dépôt Git déjà initialisé ici."
        exit 1
    fi

    echo "📁 Création dépôt '$repo_name' sur GitHub (privé: $private)..."

    response=$(curl -s -w "%{http_code}" -o /tmp/github_response.json \
      -u "$GITHUB_USER:$GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -X POST "$API_URL/user/repos" \
      -d "{\"name\":\"$repo_name\", \"private\":$private}")

    if [ "$response" = "201" ]; then
        echo "✅ Dépôt GitHub créé."
    elif [ "$response" = "422" ]; then
        echo "⚠️ Le dépôt '$repo_name' existe déjà sur GitHub."
        exit 1
    else
        echo "❌ Échec de création du dépôt. HTTP $response"
        cat /tmp/github_response.json
        exit 1
    fi

    git init
    echo "# $repo_name" > README.md
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    git branch -M main
    git remote add origin "https://github.com/$GITHUB_USER/$repo_name.git"
    git push -u origin main
    echo "✅ Dépôt local initialisé et pushé."
}

# Analyse des options
case "$1" in
    -init)
        [ -z "$2" ] && show_help
        init_repo "$2" "$3" "$4"
        ;;
    -board)
        [ -z "$2" ] && show_help
        create_board "$2"
        ;;
    -issues)
        [ -z "$2" ] && show_help
        create_issues "$2"
        ;;
    *)
        show_help
        ;;
esac

exit 0

