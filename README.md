# KILLERBEES

KILLERBEES est une station de contrôle tactique et de télémétrie iOS moderne pour drones Parrot (Anafi et compatibles), développée en SwiftUI et propulsée par un moteur de vision par ordinateur haute performance **Apple Core AI (Neural Engine / GPU)**.

L'application intègre un suivi dynamique de cibles à haute fréquence, une segmentation de silhouette thermique, une détection de boîtes orientées (OBB), ainsi qu'une interface HUD militaire et cinématographique adaptée à différents profils de mission.

---

## 🎯 Reconnaissance Ciblée (3 Catégories Strictes)

Le système d'intelligence artificielle est configuré pour filtrer et n'accepter strictement que **trois catégories de cibles** (tous les autres objets, éléments de décor ou faux positifs sont automatiquement rejetés) :

1. **👤 Personnes** :
   - Détection des silhouettes humaines (`HUMAIN`) via YOLO COCO.
   - Comptage en direct et alertes d'intrusion en mode Surveillance.

2. **🚗 Véhicules** :
   - Véhicules terrestres (`VOITURE`, `CAMION`, `BUS`, `MOTO`, `VÉLO`, `TRAIN`).
   - Véhicules aériens et maritimes (`AVION`, `HÉLICOPTÈRE`, `BATEAU`).
   - Détection de boîtes orientées (OBB) via `yolo26n-obb` (DOTAv1) et détection standard 2D via `yolo26n` (COCO).

3. **🐾 Animaux & Gibier** :
   - Animaux domestiques et sauvages (`CANIDÉ`, `FÉLIN`, `ÉQUIDÉ`, `BOVIN`, `MOUTON`, `GIBIER`, etc.).
   - Classification taxonomique précise de la faune (sanglier, cerf, chevreuil, renard, loup, lièvre, oiseau/gibier, etc.).
   - Calcul instantané du vecteur de fuite (cap en degrés, direction cardinale, vitesse estimée).

---

## 🚀 Fonctionnalités Clés

### 🧠 Moteur d'Inférence 100% Core AI (Apple Neural Engine / GPU)
- **Inférence Apple Silicon ANE (Apple Neural Engine)** :
  - `yolo26n-seg.aimodel` : Segmentation d'instances avec masque thermique fluo en temps réel accéléré par `Accelerate` (`vDSP_vsma`).
  - `yolo26n-obb.aimodel` : Boîtes englobantes orientées (OBB) avec calcul trigonométrique de l'axe et du cap de la cible.
  - `yolo26n.aimodel` : Détection 2D ultra-rapide à faible latence.
- **Verrouillage Tactique & Aimantation Magnétique (*Magnetic Snap*)** :
  - Accrochage tactile au toucher direct ou aimantation automatique vers la cible la plus proche.
  - Tracé manuel de zone d'intérêt par glissement (*drag-to-select*).
  - Modes de suivi : **LOOK-AT** (cadrage dynamique par la nacelle) et **FOLLOW-ME** (poursuite dynamique du drone).
  - Ré-accrochage intelligent automatique en cas de décrochage optique bref via Core AI.

### 🎮 Cockpit HUD Tactique & Profils de Mission
L'interface s'adapte en temps réel selon le mode de mission sélectionné :
- **Mode Chasse** : Badge cinématique avec cap azimutal, vitesse du gibier en km/h, icône de l'espèce identifiée et profil de vol réactif (lacet à 120°/s).
- **Mode Surveillance** : Détection d'intrusions, décompte des personnes, bouton de capture de preuve photo instantanée horodatée avec coordonnées GPS.
- **Mode Loisir** : Profil cinématique 4K avec lacet doux (25°/s sans saccade) et grille des tiers 3x3 pour le cadrage photographique.
- **🎯 Horizon Artificiel Militaire Central (Pitch Ladder & Heading Tape)** :
  - Échelle de tangage militaire (*Pitch Ladder*) projetée au centre de l'image vidéo avec échelons de montée continus et de descente pointillés (±10°, ±20°, ±30°).
  - Réticule central d'axe drone fixe (*Boresight Watermark* `— ⚬ —`).
  - Ruban de cap militaire supérieur (*Heading Tape*) avec boîte numérique du cap exact et graduations cardinales défilantes.
  - Indicateur d'arc de roulis supérieur (*Roll Sky Pointer*) avec triangle d'assiette mobile.
- **👁️ Mode "HUD Épuré" (Declutter / Clean Screen)** :
  - Bouton à bascule rapide dans la barre supérieure permettant de masquer instantanément les widgets secondaires (mini-carte, jauges de télémétrie annexes, barre de vol, sélecteurs) pour ne conserver que la vidéo plein écran, la visée IA et l'horizon militaire central.
- **🎮 Pilotage de Nacelle Natif SkyController** :
  - Suppression du slider tactile rigide au profit du contrôle direct et fluide via les molettes physiques de la radiocommande SkyController, libérant le champ de vision.
- **Télémétrie Complète** : Niveaux de batterie (drone et SkyController), indicateurs GPS et satellites, qualité du lien radio, état FCC, bannières d'alarmes critiques et mini-carte satellite tactique avec ligne de visée.
- **⚡ Smart RTH & Point de Non-Retour Dynamique** :
  - Calcul trigonométrique en temps réel de la distance et du temps de vol requis pour regagner le point de départ (Home).
  - Prise en compte de l'**anémomètre** embarqué : projection vectorielle du vent (vent de face pénalisant vs vent arrière favorable) et surconsommation des moteurs.
  - Jauge de batterie intelligente avec **marqueur physique du seuil de non-retour** et marge de temps sécurisée en minutes.
  - Badge HUD de retour affichant la distance, le temps estimé de retour (ETA), la vitesse du vent et l'alerte d'auto-déclenchement GroundSdk.

---

## 🛠 Architecture & Stack Technique

Le projet repose sur une architecture **MVVM** moderne et réactive, conforme aux règles strictes de concurrence Swift :

```text
KILLERBEES/
├── Core/
│   ├── DroneManager.swift          # Pilotage GroundSdk, profil de vol, télémétrie
│   ├── SmartRTHAssessment.swift    # Moteur de calcul dynamique du point de non-retour et Smart RTH
│   ├── TrackingMode.swift          # Modes de suivi de cible (Look-At, Follow-Me)
│   └── MissionMode.swift           # Définition des profils de vol et modes de mission
├── Features/
│   ├── Connection/                 # Découverte et appairage des drones
│   │   ├── Views/ContentView.swift
│   │   └── Views/DroneRow.swift
│   └── Cockpit/                    # Station de pilotage HUD et vision IA
│       ├── Controllers/
│       │   ├── CoreAIVisionTracker.swift   # Moteur YOLO natif Core AI & Accelerate
│       │   ├── VisionTrackerService.swift  # Pipeline IA, filtrage 3 catégories, tracking optique
│       │   ├── VideoController.swift       # Décodage et rendu du flux vidéo
│       │   └── DetectedObject.swift        # Modèle de données d'objet détecté (boîtes, OBB, masque)
│       └── Views/
│           ├── DroneControlView.swift              # Écran cockpit principal
│           ├── CockpitMilitaryPitchLadderHUD.swift # Horizon militaire central (Pitch Ladder, Boresight, Heading Tape)
│           ├── CockpitAITrackingOverlay.swift      # Réticules tactiques, boîtes OBB, masque thermique
│           ├── CockpitTopBar.swift                 # Barre d'état télémétrique avec bouton Declutter
│           ├── CockpitSmartBatteryBar.swift        # Jauge intelligente avec marqueur Point de Non-Retour
│           ├── CockpitSmartRTHBadge.swift          # Badge HUD d'alerte et de télémétrie RTH (vent, distance, ETA)
│           ├── CockpitGameVectorBadge.swift        # Télémétrie gibier (cap, vitesse, espèce)
│           ├── CockpitSurveillanceBadge.swift      # Télémétrie sécurité & capture preuve
│           ├── CockpitLeisureBadge.swift           # Outils cinématographiques & grille
│           └── CockpitMiniMap.swift                # Mini-carte satellite avec ligne de visée
└── Resources/
    └── Models/                     # Modèles compilés .aimodel (YOLO Core AI)
```

---

## 📱 Prérequis

- **Xcode 16.0+**
- **iOS 26.0+** (cible recommandée : iOS 27.0+ pour Apple Core AI)
- **Swift 6.2+** (concurrence stricte, `@Observable @MainActor`)
- Appareil équipé d'une puce Apple Silicon (A16 Bionic ou ultérieure pour l'accélération ANE)

---

## 📦 Installation & Dépendances

Le projet utilise **Swift Package Manager (SPM)** pour ses dépendances SDK :

- [ParrotSDK (SPM)](https://github.com/momolas/ParrotSDK.git) : Fournit `GroundSdk`, `ArsdkEngine` et `SdkCore`.
- [SwiftProtobuf](https://github.com/apple/swift-protobuf.git) : Sérialisation des messages protocolaires.

### Lancement du projet :
1. Clonez le dépôt.
2. Ouvrez `KILLERBEES.xcodeproj` dans Xcode.
3. Attendez la résolution automatique des paquets SPM.
4. Sélectionnez la cible de destination (**Appareil iOS** pour les vols réels avec GroundSdk) et compilez (`Cmd + B`).

---

## ⚠️ Permissions Requises

- **Réseau Local** (`NSLocalNetworkUsageDescription`) : Communication Wi-Fi avec le point d'accès du drone Anafi ou du SkyController.
- **Bluetooth** (`NSBluetoothAlwaysUsageDescription`) : Détection et appairage direct à faible latence.
- **Appareil Photo / Photothèque** (`NSPhotoLibraryAddUsageDescription`) : Enregistrement des captures de vol et preuves géolocalisées.
- **Localisation** (`NSLocationWhenInUseUsageDescription`) : Positionnement GPS de la station sol pour le calcul de distance relative et le Return-To-Home (RTH).

---

## 👨‍💻 Auteurs & Maintenance

Développé et maintenu par l'équipe **KILLERBEES**. Architecture moderne Swift & intégration Core AI par Jules.
