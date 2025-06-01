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

# Créer le fichier de log s'il n'existe pas et s'assurer qu'il est accessible en écriture
if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE" 2>/dev/null || {
        echo "ERROR: Impossible de créer le fichier de log $LOG_FILE. Vérifiez les permissions." >&2
        exit 102
    }
fi

# Vérifier que le fichier de log est accessible en écriture
if [[ ! -w "$LOG_FILE" ]]; then
    # Essayer de corriger les permissions
    chmod 644 "$LOG_FILE" 2>/dev/null || {
        echo "ERROR: Le fichier de log $LOG_FILE n'est pas accessible en écriture et impossible de corriger les permissions." >&2
        exit 102
    }
fi

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

    # Vérifier que le fichier de log est accessible en écriture avant d'essayer d'écrire
    if [[ ! -w "$LOG_FILE" ]] && [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
        echo "WARNING: Impossible d'écrire dans le fichier de log $LOG_FILE. Les logs ne seront pas sauvegardés." >&2
        # Continuer sans écrire dans le fichier mais afficher le message d'erreur si c'est une erreur
        if [[ "$level" == "ERROR" && -n "$code" ]]; then
            log_line="$timestamp : $user : ERROR : $message (code $code)"
            echo "$log_line" >&2
        fi
        return 0
    fi

    local log_line
    if [[ "$level" == "ERROR" && -n "$code" ]]; then
        log_line="$timestamp : $user : ERROR : $message (code $code)"
        if ! echo "$log_line" >> "$LOG_FILE" 2>/dev/null; then
            echo "WARNING: Impossible d'écrire dans le fichier de log." >&2
        fi
        echo "$log_line" >&2 # Afficher les erreurs sur stderr
    else
        log_line="$timestamp : $user : $level : $message"
        if ! echo "$log_line" >> "$LOG_FILE" 2>/dev/null; then
            echo "WARNING: Impossible d'écrire dans le fichier de log." >&2
        fi
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

    # Créer le fichier de log et s'assurer qu'il est accessible
    if ! touch "$LOG_FILE" 2>/dev/null; then
        log_message "ERROR" "Impossible de créer le fichier de log $LOG_FILE. Vérifiez les permissions." 104
        return 1
    fi

    # S'assurer que le fichier est accessible en écriture
    if [[ ! -w "$LOG_FILE" ]]; then
        chmod 644 "$LOG_FILE" 2>/dev/null || {
            log_message "ERROR" "Le fichier de log $LOG_FILE n'est pas accessible en écriture." 105
            return 1
        }
    fi

    # Sauvegarder la nouvelle configuration
    mkdir -p "$(dirname "$CONFIG_FILE")" # S'assurer que le répertoire de config existe
    echo "export LOG_DIR=\"$LOG_DIR\"" > "$CONFIG_FILE"
    echo "export LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"

    log_message "INFO" "Le chemin des logs a été mis à jour vers : $LOG_DIR"
    return 0
}

# Fonction pour diagnostiquer et corriger les problèmes de permissions
fix_log_permissions() {
    echo "Diagnostic des permissions de log..." >&2
    
    # Vérifier le répertoire parent
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        echo "Création du répertoire de logs: $(dirname "$LOG_FILE")" >&2
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    fi
    
    # Vérifier et créer le fichier de log
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Création du fichier de log: $LOG_FILE" >&2
        touch "$LOG_FILE" 2>/dev/null
    fi
    
    # Corriger les permissions
    if [[ -f "$LOG_FILE" ]] && [[ ! -w "$LOG_FILE" ]]; then
        echo "Correction des permissions du fichier de log..." >&2
        chmod 644 "$LOG_FILE" 2>/dev/null
    fi
    
    # Vérifier si le problème est résolu
    if [[ -w "$LOG_FILE" ]]; then
        echo "Permissions corrigées avec succès." >&2
        return 0
    else
        echo "Impossible de corriger les permissions. Utilisation du mode sans log." >&2
        return 1
    fi
}

# Exporter les fonctions et variables nécessaires
export -f log_message
export -f set_log_path
export LOG_DIR
export LOG_FILE
