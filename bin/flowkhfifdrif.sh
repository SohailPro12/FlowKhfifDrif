#!/usr/bin/env bash
# FlowKhfifDrif - Script principal

# Définition des variables globales
# Utilisation du répertoire personnel de l'utilisateur pour les logs
HOME_DIR="${HOME:-/home/$(whoami)}"
INSTALL_DIR="$HOME_DIR/.flowkhfifdrif"
LOG_DIR="$INSTALL_DIR/logs"
LOG_FILE="$LOG_DIR/history.log"
DOCS_DIR="$INSTALL_DIR/docs"
LIB_DIR="$INSTALL_DIR/lib"
MODE="normal"

# Création du répertoire de logs si nécessaire
mkdir -p "$LOG_DIR" 2>/dev/null || { echo "Impossible de créer le répertoire de logs dans $LOG_DIR. Vérifiez vos permissions."; exit 102; }

# Création du répertoire lib si nécessaire
mkdir -p "$LIB_DIR" 2>/dev/null || { echo "Impossible de créer le répertoire lib."; exit 102; }

# — Détection du chemin du script même via symlink —
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Activer le mode strict
set -euo pipefail

# Charger le logger
if ! source "$LIB_DIR/logger.sh"; then
  echo "ERROR: Impossible de charger logger.sh. Vérifiez que les fichiers sont correctement installés." >&2
  exit 102
fi

# Charger le parser
if ! source "$LIB_DIR/parser.sh"; then
  log_message "ERROR" "Impossible de charger parser.sh" 102
  exit 1
fi

# Fonction d'affichage de l'aide
show_help() {
    if [[ -f "$DOCS_DIR/help.txt" ]]; then
        log_message "INFO" "Affichage de l'aide utilisateur depuis docs/help.txt"
        cat "$DOCS_DIR/help.txt"
    else
        log_message "ERROR" "Fichier d'aide introuvable." 102
        echo "FlowKhfifDrif - Assistant de développement en langage naturel"
        echo ""
        echo "UTILISATION:"
        echo "  flowkhfifdrif [OPTIONS] \"commande en langage naturel\""
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help     Affiche cette aide"
        echo "  --commands     Affiche des exemples de commandes"
        echo "  -f             Exécute la commande en arrière-plan (fork)"
        echo "  -t             Exécute la commande dans un thread"
        echo "  -s             Exécute la commande dans un sous-shell"
        echo "  -l CHEMIN      Spécifie un répertoire de logs alternatif"
        echo "  -r             Réinitialise les paramètres"
        echo "  --ai           Active les fonctionnalités d'IA (si disponibles)"
    fi
}

# Fonction pour afficher les exemples de commandes
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
  echo "  └── setup board MyApp     → Crée un tableau et des issues de base"
  echo "  └── create issue \"Fix bug\" MyApp     → Crée une issue personnalisée"
  echo "  └── assign user john to issue #3 MyApp → Assigne une issue à un utilisateur"

  echo -e "\nℹ️ Utilisation :"
  echo "  flowkhfifdrif \"votre commande ici\""
  echo -e "  ex : flowkhfifdrif push into main with commit \"init project\"\n"
}

# Lecture des options
while [[ $# -gt 0 && "$1" =~ ^- ]]; do
  case "$1" in
    -h|--help)           show_help; exit 0 ;;
    --commands)          print_commands_examples; exit 0 ;;
    -f)                  MODE="fork" ;;
    -t)                  MODE="thread" ;;
    -s)                  MODE="subshell" ;;
    -l)                  shift; LOG_DIR="$1"; LOG_FILE="$LOG_DIR/history.log" ;;
    -r)                  RESET=true ;;
    --ai)                USE_AI=true ;;
    *)                   log_message "ERROR" "Option inconnue : $1" 100; exit 100 ;;
  esac
  shift
done

# Vérification de la présence d'une commande
INPUT="$*"
if [[ -z "$INPUT" && -z "${RESET:-}" ]]; then
  log_message "ERROR" "Commande manquante" 100
  show_help
  exit 100
fi

# Appel au parser seulement si une commande est fournie
if [[ -n "$INPUT" ]]; then
  # Capture la sortie du parser dans une variable
  COMMAND=$(parse_natural "$INPUT")
  PARSER_STATUS=$?
  
  if [[ $PARSER_STATUS -ne 0 ]]; then
    log_message "ERROR" "Commande non reconnue ou mal formatée" 100
    exit 100
  fi

  # Charger GitHub si besoin
  if [[ "$COMMAND" == init_remote_repo* || "$COMMAND" == create_github_* || "$COMMAND" == setup_board_and_issues* ]]; then
    if ! source "$LIB_DIR/github.sh"; then
      log_message "ERROR" "Impossible de charger github.sh" 104
      exit 104
    fi
  fi

  # Exécution de la commande selon le mode
  log_message "DEBUG" "Exécution de la commande: $COMMAND"
  
  case "$MODE" in
    fork)     bash -c "$COMMAND" & ;;
    thread)   bash -c "$COMMAND" & wait ;;
    subshell) ( eval "$COMMAND" ) ;;
    *)        eval "$COMMAND" ;;
  esac
  
  EXIT_STATUS=$?
  log_message "DEBUG" "Commande terminée avec le statut: $EXIT_STATUS"
  exit $EXIT_STATUS
fi

# Si on arrive ici avec RESET défini, on ne fait rien de spécial
exit 0
