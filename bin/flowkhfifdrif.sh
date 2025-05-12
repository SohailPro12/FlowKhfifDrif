#!/usr/bin/env bash

# === Détection du chemin du script ===
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

source "$SCRIPT_DIR/../lib/parser.sh"

# === Variables globales ===
LOG_DIR="/var/log/flowkhfifdrif"
USE_AI=false

# === Aide (-h) ===
print_help() {
  cat <<EOF
Usage: flowkhfifdrif.sh [options] <commande en langage naturel>

Options :
  -h           Affiche cette aide
  -f           Exécute la commande via fork (bash &)
  -t           Exécute dans un thread simulé (bg + wait)
  -s           Exécute dans un sous-shell
  -l <rép>     Spécifie le répertoire de log
  -r           Réinitialise la configuration (root)
  --ai         Active le mode intelligence artificielle
EOF
}

# === Lecture des options ===
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    -h) print_help; exit 0 ;;
    -f) MODE="fork" ;;
    -t) MODE="thread" ;;
    -s) MODE="subshell" ;;
    -l) shift; LOG_DIR="$1" ;;
    -r) RESET=true ;;
    --ai) USE_AI=true ;;
    *) echo "Option inconnue : $1" >&2; exit 100 ;;
  esac
  shift
done

# === Récupérer la commande en langage naturel ===
INPUT="$*"
if [[ -z "$INPUT" && -z "$RESET" ]]; then
  echo "Erreur : commande manquante" >&2
  print_help
  exit 101
fi

# === Réinitialisation ===
if [[ "$RESET" == true ]]; then
  echo "[INFO] Réinitialisation de la configuration..."
  # Appel à une fonction reset_config si besoin
  exit 0
fi

# === Analyse et exécution ===
COMMAND=$(parse_natural "$INPUT")

case "$MODE" in
  fork) bash -c "$COMMAND" & ;;
  thread) bash -c "$COMMAND" & wait ;;
  subshell) ( eval "$COMMAND" ) ;;
  *) eval "$COMMAND" ;;
esac