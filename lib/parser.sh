#!/usr/bin/env bash
# lib/parser.sh — translate natural → commands or function calls

# Importer le logger
# Utilisation du répertoire personnel de l'utilisateur pour les logs
if [[ -z "$LOG_DIR" ]]; then
  HOME_DIR="${HOME:-/home/$(whoami)}"
  LOG_DIR="$HOME_DIR/.flowkhfifdrif/logs"
fi

# Charger le logger s'il n'est pas déjà chargé
if ! type log_message &>/dev/null; then
  source "$LOG_DIR/../lib/logger.sh"
fi

parse_natural() {
  local INPUT="$*"

  # --- COMMANDES GIT LOCAL ---

  # 1) init <repo> - Inchangé car déjà court
  if [[ "$INPUT" =~ ^init[[:space:]]+([A-Za-z0-9._-]+)([[:space:]]+(true|false))?([[:space:]]+([^[:space:]]+))?$ ]]; then
    log_message "INFO" "Initialisation du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "init_remote_repo ${BASH_REMATCH[1]} ${BASH_REMATCH[3]:-false} ${BASH_REMATCH[5]:-.}"
    return 0
  fi

  # 2) clone <url> [dest] - Inchangé car déjà court
  if [[ "$INPUT" =~ ^clone[[:space:]]+([^[:space:]]+)([[:space:]]+([^[:space:]]+))?$ ]]; then
    local URL="${BASH_REMATCH[1]}"
    local D="${BASH_REMATCH[3]}"
    if [[ -n "$D" ]]; then
      log_message "INFO" "Clonage du dépôt $URL vers $D" >&2
      echo "git clone $URL $D"
    else
      log_message "INFO" "Clonage du dépôt $URL" >&2
      echo "git clone $URL"
    fi
    return 0
  fi

  # 3) add - Nouvelle commande pour git add uniquement
  if [[ "$INPUT" =~ ^add$ ]]; then
    log_message "INFO" "Ajout de tous les fichiers modifiés" >&2
    echo "git add ."
    return 0
  fi

  # 4) commit "<msg>" - Nouvelle commande pour git commit uniquement
  if [[ "$INPUT" =~ ^commit[[:space:]]+\"(.+)\"$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Commit avec message \"$MSG\"" >&2
    echo "git commit -m \"$MSG\""
    return 0
  fi

  # 5) add-commit "<msg>" - Nouvelle commande combinée pour git add + commit
  if [[ "$INPUT" =~ ^add-commit[[:space:]]+\"(.+)\"$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Ajout et commit avec message \"$MSG\"" >&2
    echo "git add . && git commit -m \"$MSG\""
    return 0
  fi

  # 6) push-<branch> "<msg>" - Version avec tiret
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)[[:space:]]+\"(.+)\"$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 6b) push <branch> "<msg>" - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^push[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+\"(.+)\"$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 6c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+commit[[:space:]]+(.+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 7) push-<branch> - Nouvelle commande pour push uniquement (sans add/commit)
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Push vers la branche $BR" >&2
    echo "git push origin $BR"
    return 0
  fi

  # 8) branch-<name> - Version avec tiret
  if [[ "$INPUT" =~ ^branch-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 8b) branch <name> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^branch[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 8c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^create[[:space:]]+a[[:space:]]+new[[:space:]]+branch[[:space:]]+called[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 9) checkout-<branch> - Version avec tiret
  if [[ "$INPUT" =~ ^checkout-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 9b) checkout <branch> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^checkout[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 9c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^switch[[:space:]]+to[[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 10) status - Inchangé car déjà court
  if [[ "$INPUT" =~ ^status$ ]]; then
    log_message "INFO" "Affichage du statut Git" >&2
    echo "git status"
    return 0
  fi

  # 10b) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^show[[:space:]]+status$ ]]; then
    log_message "INFO" "Affichage du statut Git" >&2
    echo "git status"
    return 0
  fi

  # 11) log - Inchangé car déjà court
  if [[ "$INPUT" =~ ^log$ ]]; then
    log_message "INFO" "Affichage du dernier commit" >&2
    echo "git log -1 --oneline"
    return 0
  fi

  # 11b) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^show[[:space:]]+latest[[:space:]]+commit$ ]]; then
    log_message "INFO" "Affichage du dernier commit" >&2
    echo "git log -1 --oneline"
    return 0
  fi

  # 12) pull-<branch> - Version avec tiret
  if [[ "$INPUT" =~ ^pull-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 12b) pull [branch] - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^pull([[:space:]]+([A-Za-z0-9._-]+))?$ ]]; then
    local BR="${BASH_REMATCH[2]:-main}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 12c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^pull[[:space:]]+from[[:space:]]+origin([[:space:]]+branch[[:space:]]+([A-Za-z0-9._-]+))?$ ]]; then
    local BR="${BASH_REMATCH[2]:-main}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 13) push-<branch>-test - Version avec tiret
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)-test$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # 13b) push <branch> --test - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^push[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+--test$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # 13c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^push[[:space:]]+into[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+with[[:space:]]+tests$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # --- COMMANDES DE DÉPENDANCES ET NETTOYAGE ---

  # 14) install-<library> - Version avec tiret
  if [[ "$INPUT" =~ ^install-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 14b) install <library> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^install[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 14c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^i[[:space:]]+want[[:space:]]+the[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+library$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 15) clean - Inchangé car déjà court
  if [[ "$INPUT" =~ ^clean$ ]]; then
    log_message "INFO" "Nettoyage des logs et fichiers temporaires" >&2
    echo "clean_logs_and_tmp"
    return 0
  fi

  # 15b) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^clean[[:space:]]+logs[[:space:]]+and[[:space:]]+tmp[[:space:]]+files$ ]]; then
    log_message "INFO" "Nettoyage des logs et fichiers temporaires" >&2
    echo "clean_logs_and_tmp"
    return 0
  fi

  # --- COMMANDES GITHUB REMOTE ---

  # 16) remote-<repo> - Version avec tiret
  if [[ "$INPUT" =~ ^remote-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi

  # 16b) remote <repo> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^remote[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi

  # 16c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^create[[:space:]]+remote[[:space:]]+repo[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi

  # 17) board-<repo> - Version avec tiret
  if [[ "$INPUT" =~ ^board-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  # 17b) board <repo> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^board[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  # 17c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^setup[[:space:]]+board[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  # 18) issue-<repo> "<title>" - Version avec tiret
  if [[ "$INPUT" =~ ^issue-([A-Za-z0-9._-]+)[[:space:]]+\"([^\"]+)\"$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[2]}\" pour ${BASH_REMATCH[1]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[2]}\" ${BASH_REMATCH[1]}"
    return 0
  fi

  # 18b) issue "<title>" <repo> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^issue[[:space:]]+\"([^\"]+)\"[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[1]}\" pour ${BASH_REMATCH[2]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[1]}\" ${BASH_REMATCH[2]}"
    return 0
  fi

  # 18c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^create[[:space:]]+issue[[:space:]]+\"([^\"]+)\"[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[1]}\" pour ${BASH_REMATCH[2]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[1]}\" ${BASH_REMATCH[2]}"
    return 0
  fi

  # 19) assign-<user>-<repo>-<num> - Version avec tiret
  if [[ "$INPUT" =~ ^assign-([A-Za-z0-9._-]+)-([A-Za-z0-9._-]+)-([0-9]+)$ ]]; then
    log_message "INFO" "Attribution de l'utilisateur ${BASH_REMATCH[1]} à l'issue #${BASH_REMATCH[3]} dans ${BASH_REMATCH[2]}" >&2
    echo "assign_github_issue ${BASH_REMATCH[3]} ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    return 0
  fi

  # 19b) assign <user> #<num> <repo> - Version avec espace (pour compatibilité)
  if [[ "$INPUT" =~ ^assign[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+#([0-9]+)[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Attribution de l'utilisateur ${BASH_REMATCH[1]} à l'issue #${BASH_REMATCH[2]} dans ${BASH_REMATCH[3]}" >&2
    echo "assign_github_issue ${BASH_REMATCH[2]} ${BASH_REMATCH[1]} ${BASH_REMATCH[3]}"
    return 0
  fi

  # 19c) Ancienne version (pour compatibilité)
  if [[ "$INPUT" =~ ^assign[[:space:]]+user[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+to[[:space:]]+issue[[:space:]]+#([0-9]+)[[:space:]]+([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Attribution de l'utilisateur ${BASH_REMATCH[1]} à l'issue #${BASH_REMATCH[2]} dans ${BASH_REMATCH[3]}" >&2
    echo "assign_github_issue ${BASH_REMATCH[2]} ${BASH_REMATCH[1]} ${BASH_REMATCH[3]}"
    return 0
  fi

  # Commande non reconnue
  log_message "ERROR" "Commande non reconnue: $INPUT" 100 >&2
  return 1
}
