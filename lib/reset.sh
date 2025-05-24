#!/usr/bin/env bash
# lib/reset.sh — Réinitialisation de l'environnement

# Importer le logger si nécessaire
if [[ -z "$LOG_DIR" ]]; then
  HOME_DIR="${HOME:-/home/$(whoami)}"
  LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
fi

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  # Utiliser un chemin relatif robuste
  if [[ -f "$(dirname "${BASH_SOURCE[0]}")/logger.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
  else
    echo "ERROR: Impossible de charger logger.sh depuis reset.sh" >&2
    # Définir une fonction factice pour éviter les erreurs fatales
    log_message() { echo "Logger non chargé: $@" >&2; }
  fi
fi

reset_environment() {
  # Vérifie les droits root
  if [[ "$EUID" -ne 0 ]]; then
    log_message "ERROR" "Vous devez exécuter cette commande en tant que root (utilisez sudo)." 105
    return 1
  fi

  # Corrige le HOME même avec sudo
  if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
    export HOME=$(eval echo "~$SUDO_USER")
  fi

  local config_file="$HOME/.flowkhfifdrif/config.sh"
  local logger_config_file="$HOME/.flowkhfifdrif/logger_config.sh"
  local logs_dir="$LOG_DIR" # Utiliser la variable LOG_DIR chargée par le logger

  # Charger les variables si le fichier existe
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  else
    log_message "WARN" "Fichier de configuration principal introuvable : $config_file"
  fi

  # Suppression du dépôt local si défini
  if [[ -n "${FLOW_LAST_REPO_PATH:-}" && -d "$FLOW_LAST_REPO_PATH" ]]; then
    log_message "INFO" "Suppression du dépôt local : $FLOW_LAST_REPO_PATH"
    rm -rf "$FLOW_LAST_REPO_PATH" >/dev/null 2>&1
  else
    log_message "INFO" "Aucun chemin de dépôt local trouvé à supprimer (variable FLOW_LAST_REPO_PATH non définie ou répertoire inexistant)."
  fi

  # Réinitialisation des paramètres Git
  log_message "INFO" "Réinitialisation de la configuration Git globale..."
  git config --global --unset user.name 2>/dev/null || true
  git config --global --unset user.email 2>/dev/null || true
  git config --global --remove-section credential 2>/dev/null || true

  # Réinitialisation du fichier de config principal
  log_message "INFO" "Réinitialisation du fichier de config principal : $config_file"
  mkdir -p "$(dirname "$config_file")"
  cat > "$config_file" <<EOF
# Fichier de configuration réinitialisé
export FLOW_PROJECTS_DIR="\$HOME/flow_projects"
export GITHUB_USER=""
export GITHUB_TOKEN=""
export GIT_USER_NAME=""
export GIT_USER_EMAIL=""
# Variables de dépôt supprimées
EOF

  # Réinitialisation du fichier de config du logger
  if [[ -f "$logger_config_file" ]]; then
    log_message "INFO" "Suppression du fichier de configuration du logger : $logger_config_file"
    rm -f "$logger_config_file"
  fi

  # Suppression des logs (après avoir loggué les étapes précédentes)
  if [[ -d "$logs_dir" ]]; then
    log_message "INFO" "Suppression du répertoire de logs : $logs_dir"
    rm -rf "$logs_dir" >/dev/null 2>&1
  fi

  # Message final (ne sera pas loggué si le répertoire a été supprimé)
  echo "Environnement réinitialisé avec succès."
  echo "Le logger utilisera désormais le chemin par défaut (~/.flowkhfifdrif/logs)."
  return 0
}

# Exporter la fonction
export -f reset_environment
