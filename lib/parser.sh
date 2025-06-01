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

  # --- GESTION PARALLÉLISATION AVEC && ---
  # Détecter si la commande contient && pour parallélisation
  if [[ "$INPUT" == *"&&"* ]]; then
    log_message "INFO" "Commande parallélisable détectée avec &&" >&2
    
    # Cas spécial: multiples install-<package>
    # Exemple: install-express && install-mongoose && install-dotenv
    if [[ "$INPUT" =~ ^install-[A-Za-z0-9._-]+([[:space:]]*\&\&[[:space:]]*install-[A-Za-z0-9._-]+)+$ ]]; then
      log_message "INFO" "Détection de multiples installations - optimisation en une seule commande" >&2
      
      # Extraire tous les noms de packages
      local packages=""
      local temp_input="$INPUT"
      
      # Remplacer && par des espaces et extraire les packages
      temp_input="${temp_input//&&/ }"
      
      for word in $temp_input; do
        if [[ "$word" =~ ^install-([A-Za-z0-9._-]+)$ ]]; then
          local package_name="${BASH_REMATCH[1]}"
          if [[ -n "$packages" ]]; then
            packages="$packages $package_name"
          else
            packages="$package_name"
          fi
        fi
      done
      
      if [[ -n "$packages" ]]; then
        echo "npm install $packages"
        return 0
      fi
    fi
    
    # Cas spécial: multiples clone
    # Exemple: clone url1 && clone url2
    if [[ "$INPUT" =~ clone.*\&\&.*clone ]]; then
      log_message "INFO" "Détection de multiples clones - parallélisation vraie" >&2
      
      # Pour les clones, la vraie parallélisation est bénéfique
      # Parser normalement pour permettre l'exécution parallèle
    fi
    
    # Traitement général pour autres commandes parallélisables
    local parallel_commands=""
    
    # Utiliser une approche plus simple et robuste
    # Séparer les commandes par && en préservant les espaces
    local IFS_OLD="$IFS"
    IFS='&'
    read -ra PARTS <<< "$INPUT"
    IFS="$IFS_OLD"
    
    local commands=()
    local i=0
    while [[ $i -lt ${#PARTS[@]} ]]; do
      if [[ $i -eq 0 ]]; then
        # Première partie
        commands+=("${PARTS[$i]}")
      elif [[ "${PARTS[$i]}" == "" && "${PARTS[$((i+1))]}" != "" ]]; then
        # Trouvé &&, prendre la partie suivante
        i=$((i+1))
        commands+=("${PARTS[$i]}")
      fi
      i=$((i+1))
    done
    
    # Si ça ne marche pas, essayer une approche différente
    if [[ ${#commands[@]} -le 1 ]]; then
      # Méthode alternative: remplacer && par un marqueur temporaire
      local temp_input="$INPUT"
      temp_input="${temp_input// && /|||}"
      temp_input="${temp_input//&&/|||}"
      
      IFS='|||' read -ra commands <<< "$temp_input"
    fi
    
    # Parser chaque commande
    for cmd in "${commands[@]}"; do
      # Nettoyer les espaces
      cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      
      if [[ -n "$cmd" && "$cmd" != "" ]]; then
        # Parser chaque commande individuellement
        local parsed_cmd=$(parse_single_command "$cmd")
        if [[ -n "$parsed_cmd" && "$parsed_cmd" != "" ]]; then
          if [[ -n "$parallel_commands" ]]; then
            parallel_commands="$parallel_commands && $parsed_cmd"
          else
            parallel_commands="$parsed_cmd"
          fi
        fi
      fi
    done
    
    if [[ -n "$parallel_commands" ]]; then
      echo "$parallel_commands"
      return 0
    fi
  fi

  # Sinon, parser normalement
  parse_single_command "$INPUT"
}

parse_single_command() {
  local INPUT="$1"

  # --- COMMANDES GIT LOCAL ---

  # 1) init <repo> <true|false> <path> - Initialisation d'un dépôt
  if [[ "$INPUT" =~ ^init[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+((true|false))[[:space:]]+([^[:space:]]+)$ ]]; then
    local repo_name="${BASH_REMATCH[1]}"
    local is_private="${BASH_REMATCH[2]}"
    local path="${BASH_REMATCH[4]}"
    
    log_message "INFO" "Initialisation du dépôt $repo_name (Privé: $is_private, Chemin: $path)" >&2
    echo "init_remote_repo $repo_name $is_private $path"
    return 0
  fi

  # 2) clone <url> [dest] - Clonage d'un dépôt
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

  # 3) add - Ajout de fichiers
  if [[ "$INPUT" =~ ^add$ ]]; then
    log_message "INFO" "Ajout de tous les fichiers modifiés" >&2
    echo "git add ."
    return 0
  fi

  # 4a) commit-n - Affichage des n derniers commits (DOIT ÊTRE AVANT commit <msg>)
  if [[ "$INPUT" =~ ^commit-([0-9]+)$ ]]; then
    local num_commits="${BASH_REMATCH[1]}"
    log_message "INFO" "Affichage des $num_commits derniers commits" >&2
    echo "git log -$num_commits --oneline"
    return 0
  fi

  # 4b) commit <msg> - Commit avec message (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^commit[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Commit avec message \"$MSG\"" >&2
    echo "git commit -m \"$MSG\""
    return 0
  fi

  # 5) add-commit <msg> - Ajout et commit combinés (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^add-commit[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local MSG="${BASH_REMATCH[1]}"
    log_message "INFO" "Ajout et commit avec message \"$MSG\"" >&2
    echo "git add . && git commit -m \"$MSG\""
    return 0
  fi

  # 6b) push-backup-<branch> <msg> - Push avec création de branche de sauvegarde (parallélisable)
  if [[ "$INPUT" =~ ^push-backup-([A-Za-z0-9._-]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    local BACKUP_BR="backup-$BR-$(date +%Y%m%d-%H%M%S)"
    log_message "INFO" "Push vers $BR avec création de branche de sauvegarde $BACKUP_BR" >&2
    echo "git add . && git commit -m \"$MSG\" && git checkout -b $BACKUP_BR && git checkout $BR && git push origin $BACKUP_BR && git push origin $BR"
    return 0
  fi

  # 6) push-<branch> <msg> - Push avec add, commit et message (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    local MSG="${BASH_REMATCH[2]}"
    log_message "INFO" "Push vers la branche $BR avec message de commit" >&2
    echo "git add . && git commit -m \"$MSG\" && git push origin $BR"
    return 0
  fi

  # 7) push-<branch> - Push sans add/commit
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Push vers la branche $BR" >&2
    echo "git push origin $BR"
    return 0
  fi

  # 8) branch-<name> - Création d'une branche
  if [[ "$INPUT" =~ ^branch-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création de la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout -b ${BASH_REMATCH[1]}"
    return 0
  fi

  # 9) checkout-<branch> - Basculement vers une branche
  if [[ "$INPUT" =~ ^checkout-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Basculement vers la branche ${BASH_REMATCH[1]}" >&2
    echo "git checkout ${BASH_REMATCH[1]}"
    return 0
  fi

  # 10) status - Affichage du statut Git
  if [[ "$INPUT" =~ ^status$ ]]; then
    log_message "INFO" "Affichage du statut Git" >&2
    echo "git status"
    return 0
  fi

  # 11) log - Affichage du dernier commit
  if [[ "$INPUT" =~ ^log$ ]]; then
    log_message "INFO" "Affichage du dernier commit" >&2
    echo "git log -1 --oneline"
    return 0
  fi

  # 11c) logs - Affichage du fichier history.log
  if [[ "$INPUT" =~ ^logs$ ]]; then
    log_message "INFO" "Affichage du fichier history.log" >&2
    echo "show_history_logs"
    return 0
  fi

  # 12) pull-<branch> - Pull depuis une branche
  if [[ "$INPUT" =~ ^pull-([A-Za-z0-9._-]+)$ ]]; then
    local BR="${BASH_REMATCH[1]}"
    log_message "INFO" "Pull depuis origin/$BR" >&2
    echo "git pull origin $BR"
    return 0
  fi

  # 13) push-<branch>-test - Push avec exécution des tests
  if [[ "$INPUT" =~ ^push-([A-Za-z0-9._-]+)-test$ ]]; then
    log_message "INFO" "Push vers la branche ${BASH_REMATCH[1]} avec exécution des tests" >&2
    echo "git add . && git commit -m 'auto tests' && git push origin ${BASH_REMATCH[1]} && cd Test && npm test"
    return 0
  fi

  # --- COMMANDES DE DÉPENDANCES ET NETTOYAGE ---

  # 14) install-<library> - Installation d'une bibliothèque
  if [[ "$INPUT" =~ ^install-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Installation de la bibliothèque ${BASH_REMATCH[1]}" >&2
    echo "npm install ${BASH_REMATCH[1]}"
    return 0
  fi

  # 14b) install-multi - Installation de plusieurs bibliothèques (parallélisable)
  if [[ "$INPUT" =~ ^install-multi[[:space:]]+(.+)$ ]]; then
    local libs="${BASH_REMATCH[1]}"
    log_message "INFO" "Installation parallèle de plusieurs bibliothèques: $libs" >&2
    # Convertir "lib1 lib2 lib3" en "npm install lib1 && npm install lib2 && npm install lib3"
    echo "$libs" | sed 's/[[:space:]]\+/ \&\& npm install /g' | sed 's/^/npm install /'
    return 0
  fi

  # 14c) clone-multi - Clonage de plusieurs repositories (parallélisable)
  if [[ "$INPUT" =~ ^clone-multi[[:space:]]+(.+)$ ]]; then
    local repos="${BASH_REMATCH[1]}"
    log_message "INFO" "Clonage parallèle de plusieurs repositories: $repos" >&2
    # Convertir "repo1 repo2 repo3" en "git clone repo1 && git clone repo2 && git clone repo3"
    echo "$repos" | sed 's/[[:space:]]\+/ \&\& git clone /g' | sed 's/^/git clone /'
    return 0
  fi

  # 15) clean - Nettoyage des logs et fichiers temporaires
  if [[ "$INPUT" =~ ^clean$ ]]; then
    log_message "INFO" "Nettoyage des logs et fichiers temporaires" >&2
    echo "clean_logs_and_tmp"
    return 0
  fi

  # --- COMMANDES GITHUB REMOTE ---

  # 16) remote-<repo> - Création d'un dépôt distant
  if [[ "$INPUT" =~ ^remote-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Création du dépôt distant ${BASH_REMATCH[1]}" >&2
    echo "create_github_repo ${BASH_REMATCH[1]}"
    return 0
  fi

  # 17) board-<repo> - Configuration d'un tableau
  if [[ "$INPUT" =~ ^board-([A-Za-z0-9._-]+)$ ]]; then
    log_message "INFO" "Configuration du tableau ${BASH_REMATCH[1]}" >&2
    echo "create_board ${BASH_REMATCH[1]}"
    return 0
  fi

  # 18) issue-<repo> <title> - Création d'une issue (avec ou sans guillemets)
  if [[ "$INPUT" =~ ^issue-([A-Za-z0-9._-]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
    log_message "INFO" "Création d'une issue \"${BASH_REMATCH[2]}\" pour ${BASH_REMATCH[1]}" >&2
    echo "create_github_issue \"${BASH_REMATCH[2]}\" ${BASH_REMATCH[1]}"
    return 0
  fi

  # 19) assign-<user>-<repo>-<num> - Attribution d'une issue
  # Pattern robuste pour gérer les repos avec tirets multiples
  if [[ "$INPUT" =~ ^assign-(.+)-([0-9]+)$ ]]; then
    local user_and_repo="${BASH_REMATCH[1]}"
    local issue_num="${BASH_REMATCH[2]}"
    
    # Séparer user et repo : chercher le premier tiret après "assign-"
    if [[ "$user_and_repo" =~ ^([^-]+)-(.+)$ ]]; then
      local user="${BASH_REMATCH[1]}"
      local repo_name="${BASH_REMATCH[2]}"
      
      log_message "INFO" "Attribution de l'utilisateur $user à l'issue #$issue_num dans $repo_name" >&2
      echo "assign_github_issue $issue_num $user $repo_name"
      return 0
    else
      log_message "ERROR" "Format d'assignation invalide. Utilisez: assign-<user>-<repo>-<num>" 100 >&2
      return 1
    fi
  fi

  # Commande non reconnue
  log_message "ERROR" "Commande non reconnue: $INPUT" 100 >&2
  return 1
}

# Fonction principale appelée par le script
parse_command() {
  parse_natural "$@"
}
