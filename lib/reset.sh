reset_environment() {
  # Vérifie les droits root
  if [[ "$EUID" -ne 0 ]]; then
    log_message "ERROR"  " Vous devez exécuter cette commande en tant que root (utilisez sudo)."
    return 1
  fi


  # Corrige le HOME même avec sudo
  if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
    export HOME=$(eval echo "~$SUDO_USER")
  fi

  local config_file="$HOME/.flowkhfifdrif/config.sh"
  local logs_dir="$HOME/.flowkhfifdrif/logs"

  # Charger les variables si le fichier existe
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  else
    log_message "ERROR" " Fichier de configuration introuvable : $config_file"
  fi

  # Suppression du dépôt local si défini
  if [[ -n "${FLOW_LAST_REPO_PATH:-}" && -d "$FLOW_LAST_REPO_PATH" ]]; then
    log_message "INFO" " Suppression du dépôt local : $FLOW_LAST_REPO_PATH"
    rm -rf "$FLOW_LAST_REPO_PATH" >/dev/null 2>&1

  else
    log_message "ERROR" "Aucun chemin de dépôt local trouvé à supprimer."
  fi

  # Réinitialisation des paramètres Git
  log_message "INFO" " Réinitialisation de la configuration Git…"
  git config --global --unset user.name 2>/dev/null
  git config --global --unset user.email 2>/dev/null
  git config --global --remove-section credential 2>/dev/null

  # Suppression des logs
  if [[ -d "$logs_dir" ]]; then
    log_message "INFO" " Suppression des logs : $logs_dir"
    rm -rf "$logs_dir" >/dev/null 2>&1
  fi

  # Réinitialisation du fichier de config
  log_message "INFO" "Réinitialisation du fichier de config : $config_file"
  cat > "$config_file" <<EOF
# Fichier de configuration réinitialisé
export FLOW_PROJECTS_DIR="\$HOME/flow_projects"
export GITHUB_USER=""
export GITHUB_TOKEN=""
export GIT_USER_NAME=""
export GIT_USER_EMAIL=""
# Variables de dépôt supprimées
EOF

  log_message "INFO" " Environnement réinitialisé avec succès."
  return 0
}
