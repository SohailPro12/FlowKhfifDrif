#!/usr/bin/env bash
# lib/ai.sh — Fonctions d'intégration avec l'API Gemini

# Importer le logger si nécessaire
if ! type log_message &>/dev/null; then
  if [[ -f "$(dirname "${BASH_SOURCE[0]}")/logger.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
  else
    echo "ERROR: Impossible de charger logger.sh depuis ai.sh" >&2
    log_message() { echo "Logger non chargé: $@" >&2; }
  fi
fi

# Vérification de la variable d'environnement GEMINI_API_KEY
check_gemini_api_key() {
  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    log_message "ERROR" "La variable d'environnement GEMINI_API_KEY n'est pas définie." 106
    echo "Pour utiliser l'option --ai, vous devez définir cette variable:" >&2
    echo "export GEMINI_API_KEY=\"votre_clé_api_gemini\"" >&2
    return 1
  fi
  return 0
}

# Fonction d'appel à l'API Gemini
call_gemini() {
  local prompt_text="$1"
  local api_key="$GEMINI_API_KEY"
  # Utiliser un modèle stable et adapté
  local url="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$api_key"

  # Vérifier que jq et curl sont installés
  if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    log_message "ERROR" "jq et curl sont requis pour utiliser l'option --ai." 107
    echo "Installez-les avec: sudo apt-get update && sudo apt-get install -y jq curl" >&2
    return 1
  fi

  # Préparation de la requête avec un prompt système plus précis
  read -r -d '' req_body <<EOF
{
  "system_instruction": {
    "parts": [
      {"text": "You are an expert command-line assistant. Your task is to translate the user's natural language request into a single, executable shell command. Respond ONLY with the shell command itself, without any introductory text, explanations, comments, or markdown formatting like backticks. For example, if the user asks 'list files', respond only with 'ls -la'. If the user asks 'push to main with commit message fix bug', respond only with 'git add . && git commit -m \"fix bug\" && git push origin main'. If the command is ambiguous or unsafe, respond with 'ERROR: Ambiguous or unsafe command.'"}
    ]
  },
  "contents": [
    {
      "parts": [
        {"text": "$prompt_text"}
      ]
    }
  ],
  "generation_config": {
    "temperature": 0.2,
    "max_output_tokens": 100
  }
}
EOF

  # Log de débogage pour la requête
  log_message "DEBUG" "Requête envoyée à Gemini: $req_body"

  # Appel à l'API
  local response
  response=$(curl -s -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "$req_body")

  # Log de débogage pour la réponse brute
  log_message "DEBUG" "Réponse brute de Gemini: $response"

  # Extraction de la commande avec gestion d'erreur plus robuste
  local command_text
  command_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')

  # Vérifier si la réponse contient une erreur ou est vide
  if [[ -z "$command_text" ]] || echo "$response" | jq -e '.error' > /dev/null; then
      log_message "ERROR" "Erreur de l'API Gemini ou réponse vide. Réponse: $response" 108
      echo ""
      return 1
  elif [[ "$command_text" == "ERROR:"* ]]; then
      log_message "ERROR" "Gemini a retourné une erreur: $command_text" 109
      echo ""
      return 1
  fi

  # Nettoyer la commande (supprimer les backticks si présents)
  command_text=$(echo "$command_text" | sed 's/^`\{3\}sh\{0,1\}//; s/`\{3\}$//') # Supprime ```sh et ```
  command_text=$(echo "$command_text" | sed 's/^`//; s/`$//') # Supprime `

  echo "$command_text"
  return 0
}

# Fonction principale pour le mode IA
process_ai_command() {
  local input="$1"

  # Vérifier la clé API
  if ! check_gemini_api_key; then
    return 1
  fi

  log_message "INFO" "Interrogation de Gemini pour obtenir la commande..."
  local command
  command=$(call_gemini "$input")
  local gemini_status=$?

  if [[ $gemini_status -ne 0 ]] || [[ -z "$command" ]]; then
    log_message "ERROR" "Aucune commande valide n'a été retournée par Gemini." 110
    return 1
  fi

  # Afficher la commande suggérée AVANT la confirmation
  echo "Commande proposée par Gemini:" >&2 # Afficher sur stderr pour ne pas interférer avec une éventuelle capture de sortie
  echo "  $command" >&2
  log_message "INFO" "Commande proposée par Gemini: $command"

  read -p "Exécuter? [y/N] " conf
  if [[ "$conf" =~ ^[Yy]$ ]]; then
    log_message "INFO" "Exécution de la commande: $command"
    eval "$command"
    local exec_status=$?
    log_message "DEBUG" "Commande IA terminée avec le statut: $exec_status"
    return $exec_status
  else
    log_message "INFO" "Commande annulée par l'utilisateur."
    return 0
  fi
}

# Exporter les fonctions
export -f check_gemini_api_key
export -f call_gemini
export -f process_ai_command
