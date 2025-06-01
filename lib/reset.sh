reset_environment() {
  # Vérifie les droits root
  if [[ "$EUID" -ne 0 ]]; then
    log_message "ERROR" "🔒 Vous devez exécuter cette commande en tant que root (utilisez sudo)."
    log_message "ERROR" "   Raison: La réinitialisation doit pouvoir supprimer et recréer des fichiers système."
    log_message "ERROR" "   Commande correcte: sudo flowkhfifdrif -r"
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

  # Recréer le répertoire logs avec les bonnes permissions
  log_message "INFO" " Recréation du répertoire logs avec les bonnes permissions"
  mkdir -p "$logs_dir"
  touch "$logs_dir/history.log"
  
  # Obtenir l'utilisateur réel (pas root)
  local real_user="${SUDO_USER:-$(whoami)}"
  if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
    # Si on est en sudo, donner les permissions à l'utilisateur réel
    local user_group=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
    chown -R "$SUDO_USER:$user_group" "$HOME/.flowkhfifdrif"
    chmod -R 755 "$HOME/.flowkhfifdrif"
    chmod 644 "$logs_dir/history.log"
    log_message "INFO" " Permissions ajustées pour l'utilisateur : $SUDO_USER (groupe: $user_group)"
  else
    log_message "WARN" " Exécution sans sudo - les permissions peuvent être incorrectes"
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

  # Corriger les permissions du fichier de config aussi
  if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
    local user_group=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
    chown "$SUDO_USER:$user_group" "$config_file"
    chmod 644 "$config_file"
    log_message "INFO" " Permissions du fichier de config ajustées"
  fi

  log_message "INFO" " Environnement réinitialisé avec succès."
  return 0
}
