#!/usr/bin/env bash
# FlowKhfifDrif - Script principal

# Corriger le $HOME quand on exécute avec sudo
if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
  export HOME=$(eval echo "~$SUDO_USER")
fi

# Corriger le $HOME quand on exécute avec sudo
if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
  export HOME=$(eval echo "~$SUDO_USER")
fi

# Définition des variables globales
HOME_DIR="${HOME:-/home/$(whoami)}"
INSTALL_DIR="$HOME_DIR/.flowkhfifdrif"
LIB_DIR="$INSTALL_DIR/lib"
DOCS_DIR="$INSTALL_DIR/docs"
MODE="normal"
USE_AI=false

# Création des répertoires nécessaires
mkdir -p "$LOG_DIR" || { echo "Impossible de créer le répertoire de logs dans $LOG_DIR. Vérifiez vos permissions."; exit 102; }
mkdir -p "$LIB_DIR" || { echo "Impossible de créer le répertoire lib."; exit 102; }

# Détection du chemin du script même via symlink
# Détection du chemin du script même via symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Mode strict
# Mode strict
set -euo pipefail

# Chargement des modules requis
for module in logger parser cleaner reset; do
  if ! source "$LIB_DIR/$module.sh"; then
    echo "ERROR: Impossible de charger $module.sh. Vérifiez que les fichiers sont correctement installés." >&2
    exit 102
  fi
done

# Module GitHub (non bloquant)
if ! source "$LIB_DIR/github.sh" 2>/dev/null; then
  log_message "WARN" "Impossible de charger github.sh - les commandes GitHub ne seront pas disponibles"
  for fn in create_github_repo create_board assign_github_issue create_github_issue; do
    eval "$fn() { echo \"Fonction GitHub non disponible. Vérifiez l'installation de github.sh.\"; return 1; }"
  done
fi

# Module IA (non bloquant)
if ! source "$LIB_DIR/ai.sh" 2>/dev/null; then
  log_message "WARN" "Impossible de charger ai.sh - l'option --ai ne sera pas disponible"
  process_ai_command() {
    echo "Fonction IA non disponible. Vérifiez l'installation de ai.sh."
    return 1
  }
fi

# Fonction d'affichage de l'aide
show_help() {
  if [[ -f "$DOCS_DIR/help.txt" ]]; then
    log_message "INFO" "Affichage de l'aide utilisateur depuis docs/help.txt"
    cat "$DOCS_DIR/help.txt"
  else
    log_message "ERROR" "Fichier d'aide introuvable." 102
    echo "FlowKhfifDrif - Assistant de développement en langage naturel"
    echo "\nUTILISATION:"
    echo "  flowkhfifdrif [OPTIONS] \"commande en langage naturel\""
    echo "\nOPTIONS:"
    echo "  -h, --help     Affiche cette aide"
    echo "  --commands     Affiche des exemples de commandes"
    echo "  -f             Exécute la commande en arrière-plan (fork)"
    echo "  -t             Exécute la commande dans un thread"
    echo "  -s             Exécute la commande dans un sous-shell"
    echo "  -l CHEMIN      Spécifie un répertoire de logs alternatif"
    echo "  -r             Réinitialise les paramètres"
    echo "  --ai           Active les fonctionnalités d'IA"
  fi
}

# Fonction d'affichage des exemples de commandes
print_commands_examples() {
  if [[ -f "$DOCS_DIR/commands.txt" ]]; then
    log_message "INFO" "Affichage des exemples de commandes depuis docs/commands.txt"
    cat "$DOCS_DIR/commands.txt"
  else
    log_message "ERROR" "Fichier commands.txt introuvable." 102
    echo -e "\n📘 Commandes disponibles – Exemples pratiques"
    echo -e "\n📦 Git local :"
    echo "  └── init MyApp"
    echo "  └── clone <URL>"
    echo "  └── add"
    echo "  └── commit \"message\""
    echo "  └── add-commit \"message\""
    echo "  └── push-main \"message\""
    echo "  └── push-develop"
    echo "  └── push-develop-test"
    echo "  └── status"
    echo "  └── pull-main"
    echo "  └── branch-feat-x"
    echo "  └── checkout-feat-x"
    echo "  └── log"
    echo -e "\n📘 Commandes disponibles – Exemples pratiques"
    echo -e "\n📦 Git local :"
    echo "  └── init MyApp"
    echo "  └── clone <URL>"
    echo "  └── add"
    echo "  └── commit \"message\""
    echo "  └── add-commit \"message\""
    echo "  └── push-main \"message\""
    echo "  └── push-develop"
    echo "  └── push-develop-test"
    echo "  └── status"
    echo "  └── pull-main"
    echo "  └── branch-feat-x"
    echo "  └── checkout-feat-x"
    echo "  └── log"
    echo -e "\n🔧 Dépendances et Nettoyage :"
    echo "  └── install-express"
    echo "  └── clean"
    echo "  └── install-express"
    echo "  └── clean"
    echo -e "\n☁️ GitHub Remote :"
    echo "  └── remote-MyApp"
    echo "  └── board-MyApp"
    echo "  └── issue-MyApp \"Fix bug\""
    echo "  └── assign-john-MyApp-3"
    echo "  └── remote-MyApp"
    echo "  └── board-MyApp"
    echo "  └── issue-MyApp \"Fix bug\""
    echo "  └── assign-john-MyApp-3"
    echo -e "\nℹ️ Utilisation :"
    echo "  flowkhfifdrif \"votre commande ici\""
    echo -e "  ex : flowkhfifdrif push-main \"init project\"\n"
  fi
}

# Fonctions d'exécution selon les modes
run_fork() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode fork (arrière-plan)"
  (
    source "$LIB_DIR/github.sh" 2>/dev/null || true
    source "$LIB_DIR/parser.sh" 2>/dev/null || true
    eval "$cmd"
    log_message "INFO" "Commande fork terminée: $cmd"
  ) &
  # Ne pas attendre - retourner immédiatement au script principal
  return 0
}

run_thread() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode thread (arrière-plan + attente)"
  (
    source "$LIB_DIR/github.sh" 2>/dev/null || true
    source "$LIB_DIR/parser.sh" 2>/dev/null || true
    eval "$cmd"
    log_message "INFO" "Commande thread terminée: $cmd"
  ) &
  # Attendre que tous les processus en arrière-plan se terminent
  wait $!
  return $?
}

run_subshell() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode subshell (synchrone)"
  (
    source "$LIB_DIR/github.sh" 2>/dev/null || true
    source "$LIB_DIR/parser.sh" 2>/dev/null || true
    eval "$cmd"
    EXIT_CODE=$?
    log_message "INFO" "Commande subshell terminée: $cmd (code: $EXIT_CODE)"
    return $EXIT_CODE
  )
  return $?
}

# Lecture des options
while [[ $# -gt 0 && "$1" =~ ^- ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --commands)
      print_commands_examples
      exit 0
      ;;
    -f)
      MODE="fork"
      ;;
    -t)
      MODE="thread"
      ;;
    -s)
      MODE="subshell"
      ;;
    -l)
      shift
      LOG_DIR="$1"
      LOG_FILE="$LOG_DIR/history.log"
      ;;
    -r)
      if reset_environment; then
        
        exit 0
      else
  
        exit 1
      fi
      ;;
    --ai)
      USE_AI=true
      ;;
    *)
      log_message "ERROR" "Option inconnue : $1" 100
      exit 100
      ;;
  esac
  shift

done

# Traitement de la commande
INPUT="$*"
if [[ -z "$INPUT" && -z "${RESET:-}" ]]; then
  log_message "ERROR" "Commande manquante" 100
  show_help
  exit 100
fi

# Mode IA
# Mode IA
if [[ "$USE_AI" == true ]]; then
  if ! type process_ai_command &>/dev/null; then
    log_message "ERROR" "L'option --ai nécessite le module ai.sh, qui n'a pas pu être chargé" 103
    echo "Erreur: L'option --ai n'est pas disponible. Vérifiez que ai.sh est correctement installé." >&2
    exit 103
  fi
  log_message "INFO" "Mode IA activé, traitement de la commande: $INPUT"
  process_ai_command "$INPUT"
  exit $?
fi

# Traitement normal
# Traitement normal
if [[ -n "$INPUT" ]]; then
  COMMAND=$(parse_natural "$INPUT")
  PARSER_STATUS=$?
  if [[ $PARSER_STATUS -ne 0 ]]; then
    log_message "ERROR" "Commande non reconnue ou mal formatée" 100
    exit 100
  fi
  if [[ "$COMMAND" == *"create_github_"* || "$COMMAND" == *"init_remote_repo"* || "$COMMAND" == *"create_board"* || "$COMMAND" == *"assign_github_issue"* ]]; then
  if [[ "$COMMAND" == *"create_github_"* || "$COMMAND" == *"init_remote_repo"* || "$COMMAND" == *"create_board"* || "$COMMAND" == *"assign_github_issue"* ]]; then
    if ! source "$LIB_DIR/github.sh" 2>/dev/null; then
      log_message "ERROR" "Impossible de charger github.sh pour les commandes GitHub" 104
      echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2
      exit 104
    fi
  fi
  log_message "DEBUG" "Exécution de la commande: $COMMAND"
  # Remplacer cette partie dans le script principal
case "$MODE" in
  fork)
    log_message "INFO" "Lancement de la commande en mode fork: $COMMAND"
    run_fork "$COMMAND"
    ;;
  thread)
    log_message "INFO" "Lancement de la commande en mode thread: $COMMAND"
    run_thread "$COMMAND"
    EXIT_STATUS=$?
    ;;
  subshell)
    log_message "INFO" "Lancement de la commande en mode subshell: $COMMAND"
    run_subshell "$COMMAND"
    EXIT_STATUS=$?
    ;;
  *)
    log_message "INFO" "Exécution en mode normal: $COMMAND"
    eval "$COMMAND"
    EXIT_STATUS=$?
    ;;
esac
  EXIT_STATUS=$?
  log_message "DEBUG" "Commande terminée avec le statut: $EXIT_STATUS"
  exit $EXIT_STATUS
fi

exit 0
