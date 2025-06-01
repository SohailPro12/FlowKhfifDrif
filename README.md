# FlowKhfifDrif

Un assistant de développement en langage naturel qui simplifie les commandes Git et GitHub.

## Description

FlowKhfifDrif est un outil en ligne de commande qui vous permet d'exécuter des commandes Git et GitHub en utilisant un langage naturel simplifié. Il traduit vos instructions en commandes techniques et les exécute pour vous.

## Installation

```bash
# Installer les fichiers dans le répertoire utilisateur
cp -r bin/ ~/.flowkhfifdrif/
cp -r docs/ ~/.flowkhfifdrif/
cp -r config.sh ~/.flowkhfifdrif/
cp -r lib/ ~/.flowkhfifdrif/
chmod +x ~/.flowkhfifdrif/bin/flowkhfifdrif.sh

# Créer un lien symbolique
sudo ln -sf ~/.flowkhfifdrif/bin/flowkhfifdrif.sh /usr/local/bin/flowkhfifdrif
```

## Utilisation

```bash
flowkhfifdrif [OPTIONS] "commande en langage naturel"
```

### Options

- `-h, --help` : Affiche l'aide
- `--commands` : Affiche des exemples de commandes
- `-f` : Exécute la commande en arrière-plan (fork)
- `-t` : Exécute la commande dans un thread
- `-s` : Exécute la commande dans un sous-shell
- `-l CHEMIN` : Spécifie un répertoire de logs alternatif
- `-r` : Réinitialise les paramètres
- `--ai` : Active les fonctionnalités d'IA avec Gemini

### Modes d'exécution avancés

FlowKhfifDrif offre trois modes d'exécution pour les opérations intensives:

1. **Mode Fork (-f)** : Exécute la commande en arrière-plan sans attendre sa fin. Idéal pour les tâches longues dont vous n'avez pas besoin du résultat immédiatement.

   ```bash
   # Cloner un grand dépôt en arrière-plan
   flowkhfifdrif -f "clone https://github.com/user/large-repo"

   # Pousser des modifications tout en continuant à travailler
   flowkhfifdrif -f "push-main \"Nouvelle fonctionnalité\""

   # Installer plusieurs dépendances en parallèle
   flowkhfifdrif -f "install-express"
   flowkhfifdrif -f "install-react"
   ```

2. **Mode Thread (-t)** : Exécute la commande dans un thread en arrière-plan et attend sa fin. Utile pour isoler l'exécution tout en attendant le résultat.

   ```bash
   # Récupérer les modifications et attendre que ce soit terminé
   flowkhfifdrif -t "pull-main"

   # Pousser une version critique et attendre la confirmation
   flowkhfifdrif -t "push-main \"Correction critique\""
   ```

3. **Mode Sous-shell (-s)** : Exécute la commande dans un sous-shell (environnement isolé). Pratique pour tester des commandes sans affecter l'environnement principal.

   ```bash
   # Installer des dépendances sans affecter l'environnement principal
   flowkhfifdrif -s "install-express"

   # Exécuter des commandes git dans un environnement isolé
   flowkhfifdrif -s "status"
   ```

## Exemples

```bash
flowkhfifdrif "init MyApp true ./mon-projet"
flowkhfifdrif "push-main \"Initial commit\""
flowkhfifdrif "branch-feature"
flowkhfifdrif "clean"
```

## Tests de performance

Pour tester les différents modes d'exécution:

```bash
# Test avec durée par défaut (5s)
flowkhfifdrif "test-perf"

# Test avec durée personnalisée
flowkhfifdrif "test-perf 10"

# Test des différents modes
flowkhfifdrif "test-modes"
```

## Configuration

Pour utiliser les commandes GitHub, définissez ces variables d'environnement:

```bash
export GITHUB_USER="votre_nom_utilisateur"
export GITHUB_TOKEN="votre_token"
export GIT_USER_EMAIL="votre_email"
```

Pour utiliser l'option `--ai`, définissez:

```bash
export GEMINI_API_KEY="votre_clé_api_gemini"
```
