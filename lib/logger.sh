#!/usr/bin/env bash
# lib/logger.sh — Gestion des logs avec persistance du chemin

# ====== CONFIGURATION ======
HOME_DIR="${HOME:-/home/$(whoami)}"
CONFIG_FILE="$HOME_DIR/.flowkhfifdrif/logger_config.sh" # Utiliser un nom de fichier plus spécifique

# Valeurs par défaut
DEFAULT_LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/history.log"

# Initialiser les variables avec les valeurs par défaut
LOG_DIR="$DEFAULT_LOG_DIR"
LOG_FILE="$DEFAULT_LOG_FILE"

# Charger la config si elle existe
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Créer le dossier de logs si nécessaire (utilise la valeur chargée ou par défaut)
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "ERROR: Impossible de créer le dossier de logs $LOG_DIR. Vérifiez les permissions." >&2
    exit 102
}

# ====== FONCTIONS ======

# Fonction de journalisation
log_message() {
    local level="$1"
    local message="$2"
    local code="${3:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    local user
    user=$(whoami)

    # S'assurer que LOG_FILE est bien défini
    if [[ -z "$LOG_FILE" ]]; then
        echo "ERROR: LOG_FILE n'est pas défini dans log_message." >&2
        LOG_FILE="$DEFAULT_LOG_FILE" # Fallback au défaut
    fi

    # Créer le répertoire parent si nécessaire (au cas où il aurait été supprimé)
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

    local log_line
    if [[ "$level" == "ERROR" && -n "$code" ]]; then
        log_line="$timestamp : $user : ERROR : $message (code $code)"
        echo "$log_line" >> "$LOG_FILE"
        echo "$log_line" >&2 # Afficher les erreurs sur stderr
    else
        log_line="$timestamp : $user : $level : $message"
        echo "$log_line" >> "$LOG_FILE"
        # Ne pas afficher les logs INFO/DEBUG sur stdout par défaut pour ne pas polluer la sortie des commandes
        # Décommenter si nécessaire pour le débogage
        # echo "$log_line"
    fi
}

# Fonction pour changer et persister le chemin de log
set_log_path() {
    local new_log_dir="$1"

    if [[ -z "$new_log_dir" ]]; then
        log_message "ERROR" "Aucun chemin spécifié pour le log." 101
        return 1
    fi

    # Créer le nouveau répertoire de logs
    if ! mkdir -p "$new_log_dir" 2>/dev/null; then
        log_message "ERROR" "Impossible de créer le dossier : $new_log_dir. Vérifiez les permissions." 103
        return 1
    fi

    # Mettre à jour les variables globales
    LOG_DIR="$new_log_dir"
    LOG_FILE="$LOG_DIR/history.log"

    # Sauvegarder la nouvelle configuration
    mkdir -p "$(dirname "$CONFIG_FILE")" # S'assurer que le répertoire de config existe
    echo "export LOG_DIR=\"$LOG_DIR\"" > "$CONFIG_FILE"
    echo "export LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"

    log_message "INFO" "Le chemin des logs a été mis à jour vers : $LOG_DIR"
    return 0
}

# Exporter les fonctions et variables nécessaires
export -f log_message
export -f set_log_path
export LOG_DIR
export LOG_FILE
