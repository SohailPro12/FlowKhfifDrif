#!/usr/bin/env bash
# FlowKhfifDrif - Script principal

# Corriger le $HOME quand on exécute avec sudo
if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
  export HOME=$(eval echo "~$SUDO_USER")
fi

# Définition des variables globales
HOME_DIR="${HOME:-/home/$(whoami)}"
INSTALL_DIR="$HOME_DIR/.flowkhfifdrif"
LIB_DIR="$INSTALL_DIR/lib"
DOCS_DIR="$INSTALL_DIR/docs"
LOG_DIR="$INSTALL_DIR/logs"
LOG_FILE="$LOG_DIR/history.log"
MODE="normal"
USE_AI=false

# Création des répertoires nécessaires
mkdir -p "$LOG_DIR" || { echo "Impossible de créer le répertoire de logs dans $LOG_DIR. Vérifiez vos permissions."; exit 102; }
mkdir -p "$LIB_DIR" || { echo "Impossible de créer le répertoire lib."; exit 102; }
mkdir -p "$DOCS_DIR" || { echo "Impossible de créer le répertoire docs."; exit 102; }

# Créer le fichier de log principal avec les bonnes permissions
if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE" 2>/dev/null || { 
        echo "WARNING: Impossible de créer le fichier de log $LOG_FILE. Les logs ne seront pas sauvegardés." >&2
    }
fi

# S'assurer que le fichier de log est accessible en écriture
if [[ -f "$LOG_FILE" ]] && [[ ! -w "$LOG_FILE" ]]; then
    chmod 644 "$LOG_FILE" 2>/dev/null || {
        echo "WARNING: Le fichier de log n'est pas accessible en écriture. Les logs ne seront pas sauvegardés." >&2
    }
fi

# Détection du chemin du script même via symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Mode strict
set -euo pipefail

# Vérifier et copier les fichiers de bibliothèque si nécessaires
for module in logger parser cleaner reset github; do
  if [[ ! -f "$LIB_DIR/$module.sh" ]] && [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
    cp "$SCRIPT_DIR/../lib/$module.sh" "$LIB_DIR/" || echo "WARN: Impossible de copier $module.sh vers $LIB_DIR" >&2
    chmod +x "$LIB_DIR/$module.sh" 2>/dev/null || true
  fi
done

# Chargement des modules requis
for module in logger parser cleaner reset; do
  if ! source "$LIB_DIR/$module.sh"; then
    echo "ERROR: Impossible de charger $module.sh. Vérifiez que les fichiers sont correctement installés." >&2
    exit 102
  fi
done

# Module GitHub (non bloquant)
if [[ -f "$LIB_DIR/github.sh" ]]; then
  if ! source "$LIB_DIR/github.sh"; then
    echo "WARN: Impossible de charger github.sh depuis $LIB_DIR - vérification dans le répertoire du script" >&2
    if [[ -f "$SCRIPT_DIR/../lib/github.sh" ]] && source "$SCRIPT_DIR/../lib/github.sh"; then
      echo "INFO: github.sh chargé depuis $SCRIPT_DIR/../lib/" >&2
      # Copier le fichier dans le répertoire d'installation
      cp "$SCRIPT_DIR/../lib/github.sh" "$LIB_DIR/" && chmod +x "$LIB_DIR/github.sh" && \
        echo "INFO: github.sh copié dans $LIB_DIR" >&2
    else
      echo "WARN: Impossible de charger github.sh - les commandes GitHub ne seront pas disponibles" >&2
      # Définir des fonctions fictives pour les fonctionnalités GitHub
      init_remote_repo() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
      create_github_repo() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
      create_board() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
      assign_github_issue() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
      create_github_issue() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
    fi
  fi
else
  echo "WARN: github.sh introuvable dans $LIB_DIR - vérification dans le répertoire du script" >&2
  if [[ -f "$SCRIPT_DIR/../lib/github.sh" ]] && source "$SCRIPT_DIR/../lib/github.sh"; then
    echo "INFO: github.sh chargé depuis $SCRIPT_DIR/../lib/" >&2
    # Copier le fichier dans le répertoire d'installation
    cp "$SCRIPT_DIR/../lib/github.sh" "$LIB_DIR/" && chmod +x "$LIB_DIR/github.sh" && \
      echo "INFO: github.sh copié dans $LIB_DIR" >&2
  else
    echo "WARN: Impossible de trouver github.sh - les commandes GitHub ne seront pas disponibles" >&2
    # Définir des fonctions fictives pour les fonctionnalités GitHub
    init_remote_repo() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
    create_github_repo() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
    create_board() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
    assign_github_issue() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
    create_github_issue() { echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2; return 1; }
  fi
fi

# Module IA (non bloquant)
if ! source "$LIB_DIR/ai.sh" 2>/dev/null; then
  echo "WARN: Impossible de charger ai.sh - l'option --ai ne sera pas disponible" >&2
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
    echo "FlowKhfifDrif - Assistant de développement en langage naturel"
    echo ""
    echo "UTILISATION:"
    echo "  flowkhfifdrif [OPTIONS] \"commande en langage naturel\""
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Affiche cette aide"
    echo "  --commands     Affiche des exemples de commandes"
    echo "  -f             Parallélise les traitements sans attendre"
    echo "  -t             Parallélise les traitements avec attente"
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
    echo -e "\n☁️ GitHub Remote :"
    echo "  └── remote-MyApp"
    echo "  └── board-MyApp"
    echo "  └── issue-MyApp \"Fix bug\""
    echo "  └── assign-john-MyApp-3"
    echo -e "\nℹ️ Utilisation :"
    echo "  flowkhfifdrif \"votre commande ici\""
    echo -e "  ex : flowkhfifdrif push-main \"init project\"\n"
  fi
}

# Fonction d'affichage du fichier history.log
show_history_logs() {
  log_message "INFO" "Affichage du fichier history.log"
  
  # Vérifier si le fichier de log existe
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "Aucun fichier de log trouvé à l'emplacement: $LOG_FILE" >&2
    log_message "WARN" "Fichier history.log introuvable à l'emplacement: $LOG_FILE"
    return 1
  fi
  
  # Vérifier si le fichier est lisible
  if [[ ! -r "$LOG_FILE" ]]; then
    echo "Le fichier de log n'est pas accessible en lecture: $LOG_FILE" >&2
    log_message "ERROR" "Impossible de lire le fichier history.log: $LOG_FILE" 105
    return 1
  fi
  
  # Afficher le contenu du fichier avec formatage
  echo "=== HISTORIQUE DES LOGS FlowKhfifDrif ===" >&2
  echo "Fichier: $LOG_FILE" >&2
  echo "=======================================" >&2
  
  # Vérifier si le fichier est vide
  if [[ ! -s "$LOG_FILE" ]]; then
    echo "Le fichier de log est vide." >&2
    return 0
  fi
  
  # Afficher le contenu avec une pagination si nécessaire
  if command -v less >/dev/null 2>&1; then
    # Utiliser less si disponible pour permettre la navigation
    cat "$LOG_FILE" | less -R
  else
    # Sinon afficher directement le contenu
    cat "$LOG_FILE"
  fi
  
  return 0
}

# Fonctions d'exécution selon les modes
run_fork() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode fork (parallélisation sans attente)"
  
  # Détection des sous-tâches qui peuvent être parallélisées
  local sub_tasks=()
  
  # Parser la commande pour identifier les sous-tâches potentielles
  if [[ "$cmd" == *"&&"* ]]; then
    # Vérifier si c'est une séquence git qui doit rester séquentielle
    if [[ "$cmd" == *"git add"* && "$cmd" == *"git commit"* ]] || 
       [[ "$cmd" == *"git checkout"* && "$cmd" == *"git push"* ]] ||
       [[ "$cmd" == *"npm install"* && "$cmd" == *"&&"* && "$cmd" != *"install-"*"&&"*"install-"* ]]; then
      # Ces commandes doivent rester séquentielles - ne pas paralléliser
      echo "Détection de workflow séquentiel Git/npm - exécution normale sans parallélisation" >&2
      sub_tasks=("$cmd")
    else
      # Commande avec plusieurs étapes séparées par && (vraiment parallélisables)
      IFS='&&' read -ra sub_tasks <<< "$cmd"
    fi
  else
    # Commandes spéciales qui peuvent être parallélisées
    case "$cmd" in
      "clone"*|"pull"*|"push"*|"install"*)
        # Ces commandes peuvent bénéficier de la parallélisation interne
        echo "Mode parallèle activé pour: $cmd" >&2
        ;;
    esac
    sub_tasks=("$cmd")
  fi
  
  # Si plusieurs sous-tâches sont détectées, les exécuter en parallèle
  if [[ ${#sub_tasks[@]} -gt 1 ]]; then
    echo "Parallélisation de ${#sub_tasks[@]} sous-tâches détectées" >&2
    local pids=()
    
    for task in "${sub_tasks[@]}"; do
      (
        # Charger les dépendances dans le processus enfant
        for module in github parser; do
          if [[ -f "$LIB_DIR/$module.sh" ]]; then
            source "$LIB_DIR/$module.sh" || echo "WARN: Échec du chargement de $module.sh dans le fork" >&2
          elif [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
            source "$SCRIPT_DIR/../lib/$module.sh" || echo "WARN: Échec du chargement de $SCRIPT_DIR/../lib/$module.sh dans le fork" >&2
          fi
        done
        
        # Exécuter la sous-tâche
        echo "Démarrage de la sous-tâche parallèle: $task (PID: $$)" >&2
        eval "$task"
        local exit_code=$?
        echo "Sous-tâche parallèle terminée: $task (PID: $$, Code: $exit_code)" >&2
        exit $exit_code
      ) &
      pids+=($!)
    done
    
    # Enregistrer les PIDs des processus en arrière-plan
    echo "Sous-tâches démarrées en parallèle avec PIDs: ${pids[*]}" >&2
    
    # Ne pas attendre - retourner immédiatement au script principal
    return 0
  else
    # Exécution simple en arrière-plan pour une seule tâche
    (
      # Charger les dépendances dans le processus enfant
      for module in github parser; do
        if [[ -f "$LIB_DIR/$module.sh" ]]; then
          source "$LIB_DIR/$module.sh" || echo "WARN: Échec du chargement de $module.sh dans le fork" >&2
        elif [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
          source "$SCRIPT_DIR/../lib/$module.sh" || echo "WARN: Échec du chargement de $SCRIPT_DIR/../lib/$module.sh dans le fork" >&2
        fi
      done
      
      echo "Démarrage du processus en mode fork (PID: $$)" >&2
      
      # Exécuter la commande avec parallélisation interne si possible
      case "$cmd" in
        "clone"*|"pull"*|"push"*|"install"*)
          echo "Activation de la parallélisation interne pour: $cmd" >&2
          # Ajout de l'option -j pour git ou npm si applicable
          if [[ "$cmd" == *"git clone"* ]]; then
            cmd="${cmd/git clone/git clone --jobs=4}"
          elif [[ "$cmd" == *"npm install"* ]]; then
            cmd="${cmd/npm install/npm install --no-fund --no-audit --concurrent-network-requests}"
          fi
          ;;
      esac
      
      eval "$cmd"
      local exit_code=$?
      
      echo "Processus fork terminé (PID: $$, Code: $exit_code)" >&2
      log_message "INFO" "Commande fork terminée: $cmd (code: $exit_code)"
      exit $exit_code
    ) &
    
    # Enregistrer le PID du processus en arrière-plan
    local fork_pid=$!
    echo "Processus démarré en arrière-plan avec PID: $fork_pid" >&2
    
    # Ne pas attendre - retourner immédiatement au script principal
    return 0
  fi
}

run_thread() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode thread (parallélisation avec attente)"
  
  # Détection des sous-tâches qui peuvent être parallélisées
  local sub_tasks=()
  
  # Parser la commande pour identifier les sous-tâches potentielles
  if [[ "$cmd" == *"&&"* ]]; then
    # Vérifier si c'est une séquence git qui doit rester séquentielle
    if [[ "$cmd" == *"git add"* && "$cmd" == *"git commit"* ]] || 
       [[ "$cmd" == *"git checkout"* && "$cmd" == *"git push"* ]] ||
       [[ "$cmd" == *"npm install"* && "$cmd" == *"&&"* && "$cmd" != *"install-"*"&&"*"install-"* ]]; then
      # Ces commandes doivent rester séquentielles - ne pas paralléliser
      echo "Détection de workflow séquentiel Git/npm - exécution normale sans parallélisation" >&2
      sub_tasks=("$cmd")
    else
      # Commande avec plusieurs étapes séparées par && (vraiment parallélisables)
      IFS='&&' read -ra sub_tasks <<< "$cmd"
    fi
  else
    # Commandes spéciales qui peuvent être parallélisées
    case "$cmd" in
      "clone"*|"pull"*|"push"*|"install"*)
        # Ces commandes peuvent bénéficier de la parallélisation interne
        echo "Mode parallèle activé pour: $cmd" >&2
        ;;
    esac
    sub_tasks=("$cmd")
  fi
  
  # Si plusieurs sous-tâches sont détectées, les exécuter en parallèle
  if [[ ${#sub_tasks[@]} -gt 1 ]]; then
    echo "Parallélisation de ${#sub_tasks[@]} sous-tâches détectées avec attente" >&2
    local pids=()
    
    for task in "${sub_tasks[@]}"; do
      (
        # Charger les dépendances dans le processus enfant
        for module in github parser; do
          if [[ -f "$LIB_DIR/$module.sh" ]]; then
            source "$LIB_DIR/$module.sh" || echo "WARN: Échec du chargement de $module.sh dans le thread" >&2
          elif [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
            source "$SCRIPT_DIR/../lib/$module.sh" || echo "WARN: Échec du chargement de $SCRIPT_DIR/../lib/$module.sh dans le thread" >&2
          fi
        done
        
        # Exécuter la sous-tâche
        echo "Démarrage de la sous-tâche parallèle: $task (PID: $$)" >&2
        eval "$task"
        local exit_code=$?
        echo "Sous-tâche parallèle terminée: $task (PID: $$, Code: $exit_code)" >&2
        exit $exit_code
      ) &
      pids+=($!)
    done
    
    # Enregistrer les PIDs des processus en arrière-plan
    echo "Sous-tâches démarrées en parallèle avec PIDs: ${pids[*]}" >&2
    
    # Attendre la fin de toutes les sous-tâches
    local all_status=0
    for pid in "${pids[@]}"; do
      wait $pid
      local status=$?
      if [[ $status -ne 0 ]]; then
        all_status=$status
      fi
    done
    
    log_message "INFO" "Toutes les sous-tâches parallèles sont terminées avec statut: $all_status"
    return $all_status
  else
    # Exécution simple en arrière-plan avec attente pour une seule tâche
    (
      # Charger les dépendances dans le thread
      for module in github parser; do
        if [[ -f "$LIB_DIR/$module.sh" ]]; then
          source "$LIB_DIR/$module.sh" || echo "WARN: Échec du chargement de $module.sh dans le thread" >&2
        elif [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
          source "$SCRIPT_DIR/../lib/$module.sh" || echo "WARN: Échec du chargement de $SCRIPT_DIR/../lib/$module.sh dans le thread" >&2
        fi
      done
      
      echo "Démarrage du processus en mode thread (PID: $$)" >&2
      
      # Exécuter la commande avec parallélisation interne si possible
      case "$cmd" in
        "clone"*|"pull"*|"push"*|"install"*)
          echo "Activation de la parallélisation interne pour: $cmd" >&2
          # Ajout de l'option -j pour git ou npm si applicable
          if [[ "$cmd" == *"git clone"* ]]; then
            cmd="${cmd/git clone/git clone --jobs=4}"
          elif [[ "$cmd" == *"npm install"* ]]; then
            cmd="${cmd/npm install/npm install --no-fund --no-audit --concurrent-network-requests}"
          fi
          ;;
      esac
      
      eval "$cmd"
      local exit_code=$?
      
      echo "Processus thread terminé (PID: $$, Code: $exit_code)" >&2
      log_message "INFO" "Commande thread terminée: $cmd (code: $exit_code)"
      exit $exit_code
    ) &
    
    # Enregistrer le PID du processus en arrière-plan
    local thread_pid=$!
    echo "Attente du processus en arrière-plan avec PID: $thread_pid..." >&2
    
    # Attendre que le processus se termine
    wait $thread_pid
    local wait_status=$?
    
    log_message "INFO" "Processus $thread_pid terminé avec le statut: $wait_status"
    return $wait_status
  fi
}

run_subshell() {
  local cmd="$1"
  log_message "INFO" "Exécution en mode subshell (synchrone dans un environnement isolé)"
  (
    # Charger les dépendances dans le subshell
    for module in github parser; do
      if [[ -f "$LIB_DIR/$module.sh" ]]; then
        source "$LIB_DIR/$module.sh" || echo "WARN: Échec du chargement de $module.sh dans le subshell" >&2
      elif [[ -f "$SCRIPT_DIR/../lib/$module.sh" ]]; then
        source "$SCRIPT_DIR/../lib/$module.sh" || echo "WARN: Échec du chargement de $SCRIPT_DIR/../lib/$module.sh dans le subshell" >&2
      fi
    done
    
    # Afficher des informations sur le processus
    echo "Démarrage du processus en mode subshell (PID: $$)" >&2
    
    # Exécuter la commande
    eval "$cmd"
    local exit_code=$?
    
    echo "Processus subshell terminé (PID: $$, Code: $exit_code)" >&2
    log_message "INFO" "Commande subshell terminée: $cmd (code: $exit_code)"
    return $exit_code
  )
  
  # Capturer le statut de sortie du subshell
  local subshell_status=$?
  log_message "INFO" "Sous-shell terminé avec le statut: $subshell_status"
  return $subshell_status
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
      # Re-créer le répertoire de logs avec le nouveau chemin
      mkdir -p "$LOG_DIR" || { echo "Impossible de créer le répertoire de logs dans $LOG_DIR. Vérifiez vos permissions."; exit 102; }
      ;;
    -r)
      # Vérifier si l'utilisateur a les droits sudo
      if [[ "$EUID" -ne 0 ]]; then
        echo "⚠️  ATTENTION: La commande de réinitialisation (-r) doit être exécutée avec sudo pour fonctionner correctement." >&2
        echo "   Utilisation recommandée: sudo flowkhfifdrif -r" >&2
        echo "   Continuer sans sudo peut causer des problèmes de permissions." >&2
        read -p "   Continuer quand même? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "   Opération annulée. Utilisez: sudo flowkhfifdrif -r" >&2
          exit 1
        fi
      fi
      
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
      echo "Option inconnue : $1" >&2
      exit 100
      ;;
  esac
  shift
done

# Traitement de la commande
INPUT="$*"
if [[ -z "$INPUT" && -z "${RESET:-}" ]]; then
  echo "Commande manquante" >&2
  show_help
  exit 100
fi

# Mode IA
if [[ "$USE_AI" == true ]]; then
  if ! type process_ai_command &>/dev/null; then
    echo "Erreur: L'option --ai n'est pas disponible. Vérifiez que ai.sh est correctement installé." >&2
    exit 103
  fi
  log_message "INFO" "Mode IA activé, traitement de la commande: $INPUT"
  process_ai_command "$INPUT"
  exit $?
fi

# Traitement normal
if [[ -n "$INPUT" ]]; then
  COMMAND=$(parse_natural "$INPUT")
  PARSER_STATUS=$?
  if [[ $PARSER_STATUS -ne 0 ]]; then
    echo "Commande non reconnue ou mal formatée" >&2
    exit 100
  fi
  
  if [[ "$COMMAND" == *"create_github_"* || "$COMMAND" == *"init_remote_repo"* || "$COMMAND" == *"create_board"* || "$COMMAND" == *"assign_github_issue"* ]]; then
    if ! source "$LIB_DIR/github.sh" 2>/dev/null; then
      echo "Erreur: Les commandes GitHub ne sont pas disponibles. Vérifiez l'installation de github.sh." >&2
      exit 104
    fi
  fi
  
  log_message "DEBUG" "Exécution de la commande: $COMMAND"
  
  # Exécution selon le mode
  case "$MODE" in
    fork)
      log_message "INFO" "Lancement de la commande en mode fork: $COMMAND"
      run_fork "$COMMAND"
      EXIT_STATUS=0
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
  
  log_message "DEBUG" "Commande terminée avec le statut: $EXIT_STATUS"
  exit $EXIT_STATUS
fi

exit 0