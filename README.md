# KILLERBEES

KILLERBEES est une application iOS développée en SwiftUI permettant de détecter, connecter et contrôler des drones Parrot via le **GroundSdk** et **Swift Package Manager**.

## 🚀 Fonctionnalités

- **Scan automatique** des drones à proximité.
- **Connexion sécurisée** et gestion réactive du cycle de vie des drones.
- **Streaming vidéo** en temps réel avec HUD via `UIViewRepresentable`.
- **Pilotage** basique (Décollage / Atterrissage / Arrêt d'urgence).
- **Interface Moderne** utilisant SwiftUI, `@Observable`, `@State` et `NavigationStack`.
- **Accessibilité VoiceOver** intégrée sur les indicateurs et contrôles.

## 🛠 Architecture

Le projet suit une architecture **MVVM** (Model-View-ViewModel) modulaire et réactive :

- **Models** : Objets et protocoles `Drone` / `DeviceState` fournis par GroundSdk.
- **ViewModels** :
  - `DroneManager` : Gère la découverte, la connexion et les ordres de vol.
  - `VideoController` : Gère le flux vidéo live et le serveur de stream.
- **Views** :
  - `ContentView` : Liste réactive des drones détectés avec statut de connexion.
  - `DroneRow` : Ligne d'affichage accessible pour chaque drone.
  - `DroneControlView` : Écran principal de pilotage et de streaming.
  - `VideoSection` / `VideoPlayerView` : Rendu du stream vidéo matériel.
  - `ControlButtonsSection` : Boutons d'action contextuels (Décollage / Atterrissage).

## 📱 Prérequis

- **Xcode 16.0+**
- **iOS 26.0+**
- **Swift 6.2+**

## 📦 Installation & Dépendances

Le projet utilise **Swift Package Manager (SPM)** pour ses dépendances :

- [ParrotSDK (SPM)](https://github.com/momolas/ParrotSDK.git) fournissant `GroundSdk`, `ArsdkEngine` et `SdkCore`.

Pour ouvrir et lancer le projet :
1. Clonez ce dépôt.
2. Ouvrez `KILLERBEES.xcodeproj` directement dans Xcode.
3. Les dépendances Swift Package Manager se résoudront automatiquement.
4. Sélectionnez votre destination (Simulateur ou appareil iOS) et lancez l'application (`Cmd + R`).

## ⚠️ Permissions requises

L'application utilise le Wi-Fi et le Bluetooth pour communiquer avec les drones. Assurez-vous que les permissions suivantes sont configurées pour les tests sur appareil réel :
- **Local Network Usage Description** (`NSLocalNetworkUsageDescription`)
- **Bluetooth Always Usage Description** (`NSBluetoothAlwaysUsageDescription`)

## 👨‍💻 Auteurs & Maintenance

Projet développé et maintenu par l'équipe KILLERBEES.
Architecture et modernisation SwiftUI / SPM par Jules.
