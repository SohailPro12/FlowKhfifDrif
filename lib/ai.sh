#!/usr/bin/env bash
# lib/ai.sh — Fonctions d'intégration avec l'API Gemini

# Vérification de la variable d'environnement GEMINI_API_KEY
check_gemini_api_key() {
  if [[ -z "$GEMINI_API_KEY" ]]; then
    echo "Erreur: La variable d'environnement GEMINI_API_KEY n'est pas définie." >&2
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
  local url="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$api_key"

  # Vérifier que jq et curl sont installés
  if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    echo "Erreur: jq et curl sont requis pour utiliser l'option --ai." >&2
    echo "Installez-les avec: sudo apt-get install -y jq curl" >&2
    return 1
  fi

  # Préparation de la requête
  read -r -d '' req <<EOF
{
  "systemInstruction": {
    "parts": [
      { "text": "You are a CLI assistant. Reply only with the shell command, no explanations." }
    ]
  },
  "contents": [
    {
      "parts": [
        { "text": "$prompt_text" }
      ]
    }
  ]
}
EOF

  # Appel à l'API
  local response
  response=$(curl -s -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "$req")

  # Extraction de la commande
  echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty'
}

# Fonction principale pour le mode IA
process_ai_command() {
  local input="$1"
  
  # Vérifier la clé API
  if ! check_gemini_api_key; then
    return 1
  fi

  echo ">> Interrogation de Gemini pour obtenir la commande..."
  local command
  command=$(call_gemini "$input")
  
  if [[ -z "$command" ]]; then
    echo "Erreur: Aucune commande valide n'a été retournée par Gemini." >&2
    return 1
  fi

  echo ">> Commande proposée: $command"
  read -p "Exécuter? [y/N] " conf
  if [[ "$conf" =~ ^[Yy]$ ]]; then
    eval "$command"
    return $?
  else
    echo "Commande annulée."
    return 0
  fi
}

# Exporter les fonctions
export -f check_gemini_api_key
export -f call_gemini
export -f process_ai_command
