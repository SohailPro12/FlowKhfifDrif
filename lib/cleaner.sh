#!/usr/bin/env bash
# lib/cleaner.sh — Fonctions de nettoyage

# Importer le logger si nécessaire
if [[ -z "$LOG_DIR" ]]; then
  HOME_DIR="${HOME:-/home/$(whoami)}"
  LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
fi

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  source "$LOG_DIR/../lib/logger.sh"
fi

# Fonction de nettoyage des logs et fichiers temporaires
clean_logs_and_tmp() {
    echo "Nettoyage des fichiers temporaires et des logs..."

    # Suppression des fichiers temporaires appartenant à l'utilisateur courant dans /tmp/
    if [[ -d /tmp ]]; then
        find /tmp -type f -user "$(whoami)" -exec rm -f {} \; 2>/dev/null || true
        log_message "INFO" "Fichiers temporaires supprimés."
    else
        log_message "ERROR" "Le répertoire /tmp/ n'existe pas." 102
    fi

    # Suppression des fichiers de log dans $LOG_DIR
    if [[ -d "$LOG_DIR" ]]; then
        log_message "INFO" "Réinitialisation du fichier de log."
        cat /dev/null > "$LOG_FILE"
    else
        log_message "ERROR" "Le répertoire de logs spécifié n'existe pas." 102
    fi
}

# Exporter les fonctions
export -f clean_logs_and_tmp
