# KILLERBEES

KILLERBEES est une application iOS développée en SwiftUI permettant de contrôler des drones Parrot via le **GroundSdk**.

## 🚀 Fonctionnalités

- **Scan automatique** des drones à proximité.
- **Connexion** fiable avec gestion d'état.
- **Streaming vidéo** en temps réel (HUD).
- **Pilotage** basique (Décollage / Atterrissage).
- **Interface Moderne** utilisant SwiftUI et NavigationStack.

## 🛠 Architecture

Le projet suit une architecture **MVVM** (Model-View-ViewModel) modulaire :

- **Models** : Les objets `Drone` fournis par le SDK.
- **ViewModels** :
  - `DroneManager` : Gère la liste des drones, la connexion globale et le pilotage (décollage/atterrissage).
  - `VideoController` : Gère le flux vidéo et le serveur de stream.
- **Views** :
  - `ContentView` : Liste des drones et navigation.
  - `DroneControlView` : Interface de pilotage.
  - `VideoPlayerView` : Intégration `UIViewRepresentable` du flux vidéo GroundSdk.

## 📱 Prérequis

- **Xcode 15.0+** (pour le support de la syntaxe Swift moderne).
- **iOS 26.0+**.
- **CocoaPods** pour la gestion des dépendances.

## 📦 Installation

1. Clonez ce dépôt.
2. Installez les dépendances (si nécessaire) :
   ```bash
   pod install
   ```
3. Ouvrez le fichier `.xcworkspace`.
4. Sélectionnez votre cible (iPhone ou iPad) et lancez l'application.

## ⚠️ Note sur l'environnement de développement

Ce projet utilise `Parrot GroundSdk`. Assurez-vous d'avoir les permissions nécessaires (Réseau local, Bluetooth) configurées dans le fichier `Info.plist` pour détecter les drones réels.

## 👨‍💻 Auteurs

Projet maintenu par l'équipe KILLERBEES.
Refactoring et Modernisation par Jules.
