#!/usr/bin/env bash

# — Détection du chemin du script même via symlink —
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Charger le parser
if ! source "$SCRIPT_DIR/../lib/parser.sh"; then
  echo "❌ Impossible de charger parser.sh" >&2
  exit 1
fi
# Charger logger
if ! source "$SCRIPT_DIR/../lib/logger.sh"; then
  echo "❌ Impossible de charger logger.sh" >&2
  exit 1
fi


LOG_DIR="/var/log/flowkhfifdrif"
MODE="normal"

print_help() {
  cat <<EOF
Usage: flowkhfifdrif.sh [options] <commande>

Options :
  -h           Affiche l’aide
  --commands   Liste des commandes et exemples  
  -f           Fork
  -t           Thread
  -s           Sous-shell
  -l <rép>     Répertoire de log
  -r           Réinitialisation
  --ai         Mode IA
EOF
}

print_commands_examples() {
  echo -e "\n📘 Commandes disponibles – Exemples pratiques\n"

  echo "📦 Git local :"
  echo "  └── init MyApp                        → Initialise un nouveau repo local"
  echo "  └── clone <URL>                       → Clone un repo distant"
  echo "  └── push into main with commit msg   → Git add + commit + push sur une branche"
  echo "  └── push into develop with tests     → Push + lancer tests"
  echo "  └── show status                      → Affiche l'état du dépôt"
  echo "  └── pull from origin                 → Récupère les dernières modifs"
  echo "  └── create a new branch called feat-x"
  echo "  └── switch to branch feat-x"

  echo -e "\n🔧 Dépendances et Nettoyage :"
  echo "  └── i want the express library        → Installe express avec npm"
  echo "  └── clean logs and tmp files          → Nettoie les logs et fichiers temporaires"

  echo -e "\n☁️ GitHub Remote :"
  echo "  └── create remote repo MyApp         → Crée un repo GitHub et le relie localement"
  echo "  └── setup board and issues MyApp     → Crée un tableau et des issues de base"
  echo "  └── create issue \"Fix bug\" MyApp     → Crée une issue personnalisée"
  echo "  └── assign user john to issue #3 MyApp → Assigne une issue à un utilisateur"

  echo -e "\nℹ️ Utilisation :"
  echo "  flowkhfifdrif \"votre commande ici\""
  echo -e "  ex : flowkhfifdrif push into main with commit \"init project\"\n"
}


# Lecture des options
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    -h)           print_help; exit 0 ;;
    --commands)   print_commands_examples; exit 0 ;;
    -f)           MODE="fork" ;;
    -t)           MODE="thread" ;;
    -s)           MODE="subshell" ;;
    -l) shift; LOG_DIR="$1" ;;
    -r)           RESET=true ;;
    --ai)         USE_AI=true ;;
    *)            echo "Option inconnue : $1" >&2; exit 100 ;;
  esac
  shift
done

INPUT="$*"
if [[ -z "$INPUT" && -z "$RESET" ]]; then
  echo "Erreur : commande manquante" >&2
  print_help; exit 101
fi

# Appel au parser
COMMAND=$(parse_natural "$INPUT") || handle_error 100 "Commande non reconnue ou mal formatée"

# Charger GitHub si besoin
if [[ "$COMMAND" == init_remote_repo* || "$COMMAND" == create_github_* || "$COMMAND" == setup_board_and_issues* ]]; then
  if ! source "$SCRIPT_DIR/../lib/github.sh"; then
    handle_error 104 "Impossible de charger github.sh"
  fi
fi

# Dispatch
case "$MODE" in
  fork)     bash -c "$COMMAND" & ;;
  thread)   bash -c "$COMMAND" & wait ;;
  subshell) ( eval "$COMMAND" ) ;;
  *)        eval "$COMMAND" ;;
esac

