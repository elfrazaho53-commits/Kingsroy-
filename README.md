# Rallye Ivoire 🏁🇨🇮

Jeu de rallye arcade **3D** pour mobile (Android) développé avec **Godot 4**.
Parcours les pistes de Côte d'Ivoire : Grand-Bassam, Abidjan, Yamoussoukro, Man et le Parc du Comoé.

## Fonctionnalités

- **5 étapes 3D** générées procéduralement (thèmes : côte, ville, savane, montagne)
- **Championnat** en 5 étapes avec points, progression sauvegardée
- **Course rapide** avec sélection d'étape et records personnels
- **Garage** : 3 voitures (Taxi Abidjan, 4x4 Tonkoui, Wari RS Proto) à acheter avec l'argent gagné
- **Physique arcade** : dérapages, frein à main, pénalité hors-piste
- **Checkpoints** avec chrono et objectif de temps par étape
- **Contrôles tactiles** (boutons à l'écran) + clavier pour tester sur PC
- **Sauvegarde automatique** (argent, voitures, records, championnat)

## Contrôles

| Action | Tactile | Clavier |
|---|---|---|
| Accélérer | ▲ | W / ↑ |
| Freiner / Marche arrière | ▼ | S / ↓ |
| Tourner | ◀ ▶ | A/D ou ←/→ |
| Frein à main | F | Espace |
| Réinitialiser sur la piste | ↺ | R |
| Pause | II | Échap |

## Lancer le projet

1. Installer [Godot 4.2+](https://godotengine.org/download) (version standard, pas .NET nécessaire)
2. Ouvrir Godot → **Importer** → sélectionner le dossier du projet (le fichier `project.godot`)
3. Appuyer sur **F5** (ou le bouton ▶) pour lancer le jeu

## Exporter vers Android (APK / Play Store)

### Préparation (une seule fois)

1. Installer **Android Studio** (fournit le SDK et les outils)
2. Dans Godot : `Éditeur → Paramètres de l'éditeur → Export → Android`, renseigner :
   - **Android SDK Path** (ex. `C:\Users\toi\AppData\Local\Android\Sdk`)
   - **Java SDK Path** (celui d'Android Studio : `...\Android Studio\jbr`)
3. `Projet → Installer les modèles de build Android` (télécharge les templates)
4. Créer un **keystore de release** (à conserver précieusement, jamais commité) :

```bash
keytool -genkeypair -v -keystore rallye-ivoire-release.keystore -alias rallyeivoire \
  -keyalg RSA -keysize 2048 -validity 10000
```

5. Dans Godot : `Projet → Export → Android` (le preset est déjà configuré :
   package `com.rallyeivoire.game`, arm64 + armeabi-v7a, écran panoramique immersif)
   - Onglet **Keystore** : renseigner le chemin + mots de passe du keystore de release
6. **Exporter le projet** → `.apk` (test) ou cocher **Export format AAB** pour le Play Store

> 💡 Pour tester sans compte développeur : activer le mode développeur + débogage USB sur ton
> téléphone, puis `Fichier → Télécharger sur Android` depuis Godot.

### Publication sur le Google Play Store

1. Créer un compte [Google Play Console](https://play.google.com/console) (frais unique ~25 $)
2. **Créer une application** : nom `Rallye Ivoire`, type *Jeu*, gratuit ou payant
3. Préparer le listing :
   - Icône 512×512 PNG (exporter `icon.svg`)
   - Bannière 1024×500
   - 2 à 8 **captures d'écran** de téléphone (lance le jeu et capture)
   - Description courte et complète
4. Remplir **Classification du contenu** (questionnaire) et **Sécurité des données**
   (ce jeu ne collecte aucune donnée → déclarer "aucune donnée collectée")
5. Créer une release (production ou test interne) et téléverser le `.aab` signé
6. Soumettre à la validation (quelques jours)

## Structure du projet

```
project.godot          Configuration (autoload, rendu mobile, paysage)
icon.svg               Icône du jeu
scenes/
  main_menu.tscn       Menu principal
  garage.tscn          Garage / boutique de voitures
  stage.tscn           Scène de course (piste générée + voiture + HUD)
scripts/
  game_state.gd        Autoload : sauvegarde, argent, records, progression
  stage_defs.gd        Données : 5 étapes + 3 voitures
  track_builder.gd     Génération procédurale de la piste 3D (route, décors, checkpoints)
  car.gd               Physique arcade de la voiture (CharacterBody3D)
  race_hud.gd          HUD, chronomètre, contrôles tactiles, pause, résultats
  main_menu.gd         Menu + sélection d'étape
  garage.gd            Garage
```

## Personnalisation

- **Ajouter une étape** : ajouter une entrée dans `STAGES` (`scripts/stage_defs.gd`)
  — `seed` contrôle la forme de la piste, `theme` les décors (`coast`, `city`, `savane`, `montagne`)
- **Ajouter une voiture** : ajouter une entrée dans `CARS`
  — `top_speed` (m/s), `accel`, `grip` (plus haut = plus collé à la route)
- **Ajouter de la musique** : déposer un `.ogg` dans `assets/` et jouer via un `AudioStreamPlayer`
  dans `main_menu.gd` et `stage.gd`

## Idées pour la suite (v2)

- Sons moteur (AudioStreamGenerator) et bruitages de dérapage
- Mode 2 joueurs, adversaires IA
- Replay, classements en ligne
- Publicités récompensées (AdMob) pour gagner de l'argent in-game
