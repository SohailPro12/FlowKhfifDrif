#!/bin/bash

# ------------------ CONFIG ------------------ #
: "${GITHUB_USER:?Variable GITHUB_USER non définie}"
: "${GITHUB_TOKEN:?Variable GITHUB_TOKEN non définie}"
API_URL="https://api.github.com"
GRAPHQL_API_URL="https://api.github.com/graphql" # New: GraphQL API endpoint
# ------------------------------------------- #

# Vérifier si Git est installé
if ! command -v git &> /dev/null; then
    echo "Git n'est pas installé. Veuillez l’installer pour continuer."
    exit 1
fi

# Vérifier si jq est installé
if ! command -v jq &> /dev/null; then
    echo "'jq' n'est pas installé. Veuillez l’installer pour analyser les réponses JSON."
    echo " Ex: sudo apt-get install jq (Debian/Ubuntu) ou brew install jq (macOS)"
    exit 1
fi


# Fonction d'affichage d'aide
show_help() {
    echo "Usage: $0 [OPTION] [ARGUMENTS]"
    echo ""
    echo "Options:"
    echo "  -init nom_repo [true|false] [chemin]    Initialise un dépôt Git"
    echo "  -board nom_repo                         Crée un tableau de bord pour un dépôt existant"
    echo "  -issues nom_repo                        Crée des issues pour un dépôt existant"
    exit 1
}

# Fonction pour créer un tableau de bord (GitHub Project V2 via GraphQL)
create_board() {
    local repo_name="$1"
    echo " Création du tableau de bord (Project V2) pour '$repo_name'..."

    # 1. Get the viewer's user ID (required to create a user-owned project)
    user_id_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST "$GRAPHQL_API_URL" \
        -H "Content-Type: application/json" \
        -d '{ "query": "query { viewer { id } }" }')

    user_id=$(echo "$user_id_response" | jq -r '.data.viewer.id')

    if [ -z "$user_id" ] || [ "$user_id" == "null" ]; then
        echo " Échec de l'obtention de l'ID utilisateur GitHub. Vérifiez votre GITHUB_TOKEN et sa validité."
        echo "Réponse: $user_id_response"
        return 1
    fi

    # 2. Create the Project V2
    # The project is created at the user level, not directly tied to a repo at creation time.
    # We will link issues to it later.
    create_project_mutation=$(cat <<EOF
mutation {
  createProjectV2(input: {ownerId: "$user_id", title: "Tableau de bord $repo_name"}) {
    projectV2 {
      id
      title
      url
    }
  }
}
EOF
)

    project_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST "$GRAPHQL_API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$(echo "$create_project_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}")

    project_id=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.id')
    project_url=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.url')

    if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
        echo " Tableau de bord (Project V2) créé avec l’ID: $project_id"
        echo " URL du tableau de bord: $project_url"
        echo " Création des colonnes (champs personnalisés) et ajout d'éléments..."

        # The new Project V2 doesn't use 'columns' in the same way.
        # Instead, you define custom fields. The most common is a 'Status' field
        # with options like "To Do", "In Progress", "Done".

        # 3. Add a 'Status' custom field
        create_field_mutation=$(cat <<EOF
mutation {
  createProjectV2Field(input: {projectId: "$project_id", name: "Status", dataType: SINGLE_SELECT}) {
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

        status_field_id=$(echo "$field_response" | jq -r '.data.createProjectV2Field.projectV2Field.id')
        to_do_option_id=$(echo "$field_response" | jq -r '.data.createProjectV2Field.projectV2Field.options[] | select(.name == "To Do") | .id')
        in_progress_option_id=$(echo "$field_response" | jq -r '.data.createProjectV2Field.projectV2Field.options[] | select(.name == "In Progress") | .id')
        done_option_id=$(echo "$field_response" | jq -r '.data.createProjectV2Field.projectV2Field.options[] | select(.name == "Done") | .id')


        if [ -n "$status_field_id" ] && [ "$status_field_id" != "null" ]; then
            echo " Champ 'Status' créé avec l’ID: $status_field_id"
            # You'd typically then fetch the options for the 'Status' field
            # GitHub automatically creates "To Do", "In Progress", "Done" for single select fields when created.

            # You can optionally link the repository to the project for better integration (not strictly necessary for issues)
            # This requires the project to be an organization project if you want to link it to many repositories.
            # For user projects, it's often implied.

            # Now, get the repository ID to link it to the project (for visibility/search within the project)
            repo_id_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
                -X POST "$GRAPHQL_API_URL" \
                -H "Content-Type: application/json" \
                -d "{ \"query\": \"query { repository(owner: \\\"$GITHUB_USER\\\", name: \\\"$repo_name\\\") { id } }\" }")

            repo_id=$(echo "$repo_id_response" | jq -r '.data.repository.id')

            if [ -n "$repo_id" ] && [ "$repo_id" != "null" ]; then
                echo " Ajout du dépôt '$repo_name' au Project V2..."
                add_repo_to_project_mutation=$(cat <<EOF
mutation {
  addProjectV2Item(input: {projectId: "$project_id", contentId: "$repo_id"}) {
    item {
      id
    }
  }
}
EOF
)
                curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
                    -X POST "$GRAPHQL_API_URL" \
                    -H "Content-Type: application/json" \
                    -d "{\"query\": \"$(echo "$add_repo_to_project_mutation" | tr -d '\n' | sed 's/"/\\"/g')\"}" > /dev/null
                echo " Dépôt '$repo_name' ajouté au Project V2."
            else
                echo " Impossible de récupérer l'ID du dépôt '$repo_name'. Impossible de l'ajouter au projet."
            fi

            # Now, create issues and add them to the project with their status
            # This would be more logical to do in the create_issues function
            # For now, we just indicate success for board creation.
            echo " Configuration initiale du Project V2 terminée. Vous pouvez maintenant y ajouter des issues."

        else
            echo " Échec de la création du champ 'Status'. Réponse : $field_response"
            return 1
        fi
    else
        echo " Échec de création du tableau (Project V2). Réponse : $project_response"
        return 1
    fi
}

# Fonction pour créer des issues
create_issues() {
    local repo_name="$1"
    echo " Création des issues pour '$repo_name'..."

    repo_check=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "$GITHUB_USER:$GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_USER/$repo_name")

    if [ "$repo_check" != "200" ]; then
        echo " Le dépôt '$repo_name' n'existe pas ou n’est pas accessible."
        return 1
    fi

    # Get the repository ID (needed for adding issues to Project V2)
    repo_id_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST "$GRAPHQL_API_URL" \
        -H "Content-Type: application/json" \
        -d "{ \"query\": \"query { repository(owner: \\\"$GITHUB_USER\\\", name: \\\"$repo_name\\\") { id } }\" }")

    repo_node_id=$(echo "$repo_id_response" | jq -r '.data.repository.id')

    if [ -z "$repo_node_id" ] || [ "$repo_node_id" == "null" ]; then
        echo " Impossible d'obtenir l'ID de nœud du dépôt '$repo_name'. Les issues ne pourront pas être liées aux Projects V2."
        # We'll continue to create issues, but without linking them to a project for now
    fi


    declare -A issues=(
        ["Configuration initiale du projet"]="Mettre en place l’environnement de développement."
        ["Rédiger la documentation du projet"]="Créer une documentation claire et complète."
        ["Mettre en place les tests"]="Écrire des tests unitaires et d’intégration."
    )

    for title in "${!issues[@]}"; do
        body="${issues[$title]}"
        
        # Create the issue using the REST API (still valid)
        issue_response=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" \
            -X POST "$API_URL/repos/$GITHUB_USER/$repo_name/issues" \
            -H "Accept: application/vnd.github+json" \
            -d "{\"title\":\"$title\", \"body\":\"$body\"}")
        
        issue_number=$(echo "$issue_response" | jq -r '.number')
        issue_node_id=$(echo "$issue_response" | jq -r '.node_id')

        if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
            echo " Issue '$title' créée (Numéro: $issue_number)."

            # Now, try to add the issue to the Project V2 (if a project was created)
            # To do this robustly, you would need to get the project ID
            # For this example, we'll assume you would pass the project_id or retrieve it.
            # For simplicity, we'll just print a message about linking issues.

            echo " Pour lier cette issue à un Project V2, vous devrez obtenir l'ID du Project V2 et utiliser une mutation GraphQL 'addProjectV2Item'."
            echo "   Ex: https://docs.github.com/en/graphql/guides/managing-projects#add-an-item-to-a-project"
        else
            echo " Échec de la création de l'issue '$title'. Réponse: $issue_response"
        fi
    done

    echo " Processus de création d'issues terminé."
}

# Vérifier les arguments
if [ "$#" -lt 1 ]; then
    show_help
fi

# Traitement des options
case "$1" in
    -init)
        REPO_NAME="$2"
        PRIVATE="${3:-false}"
        TARGET_DIR="${4:-.}"

        if [ -z "$REPO_NAME" ]; then
            show_help
        fi

        [ ! -d "$TARGET_DIR" ] && mkdir -p "$TARGET_DIR"

        cd "$TARGET_DIR" || exit 1

        if [ -d ".git" ]; then
            echo " Dépôt Git déjà initialisé ici."
            exit 1
        fi

        echo " Création du dépôt '$REPO_NAME' sur GitHub (privé: $PRIVATE)..."

        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -u "$GITHUB_USER:$GITHUB_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            -X POST "$API_URL/user/repos" \
            -d "{\"name\":\"$REPO_NAME\", \"private\":$PRIVATE}")

        if [ "$response" = "201" ]; then
            echo " Dépôt créé sur GitHub."
        elif [ "$response" = "422" ]; then
            echo " Dépôt déjà existant sur GitHub."
            exit 1
        else
            echo " Erreur. Code HTTP: $response"
            exit 1
        fi

        git init
        git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
        echo "# $REPO_NAME" > README.md
        echo "node_modules/" > .gitignore

        git add .
        git commit -m "Initial commit"
        git branch -M main
        git push -u origin main

        echo " Dépôt local initialisé et pushé."
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
