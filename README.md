# RechercheGazeboServeur

Serveur de simulation (Gazebo, ROS 1 Noetic dans Docker) du jumeau numérique du robot
TIAGo Dual. Le client Unity est le dépôt
[RechercheClientUnity](https://github.com/SkyfrostFR/RechercheClientUnity).

## Architecture

```
 ┌──────── client Unity ─────────┐   WebSocket   ┌──────── serveur (ce dépôt) ────────┐
 │ jumeau du robot, VR, ROS#     │  JSON :9090   │ Docker · ROS 1 Noetic              │
 │                               │ ────────────► │ rosbridge                          │
 │                               │ ◄──────────── │ Gazebo · TIAGo Dual + contrôleurs  │
 └───────────────────────────────┘               │ table et objets à saisir           │
                                                 └────────────────────────────────────┘
```

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Image ROS 1 Noetic avec la simulation PAL du TIAGo Dual et rosbridge |
| `run_sim.sh` | Lance la simulation (rosbridge sur le port 9090) |
| `pixi.toml` | Commandes d'installation et de lancement |
| `stageir_sim/` | Paquet ROS : launch, objets à saisir, réglages attendus par le client |

## Installation

Il faut un PC Linux avec **Docker**, **[pixi](https://pixi.sh)** et un affichage
graphique (pour la fenêtre Gazebo).

```bash
git clone https://github.com/SkyfrostFR/RechercheGazeboServeur.git
cd RechercheGazeboServeur
pixi run build             # construit l'image Docker (long la première fois)
```

## Lancer

```bash
pixi run sim               # avec la fenêtre Gazebo
pixi run sim-headless      # sans fenêtre
pixi run stop              # arrête la simulation
```

`pixi run sim` construit l'image si elle manque. Le client se connecte ensuite à
`ws://<adresse IP de ce PC>:9090`.

`pixi task list` affiche toutes les commandes, dont les tests automatiques
(`probe`, `world-probe`), qui attendent le client cloné à côté de ce dépôt.

Attention : rosbridge n'a pas d'authentification. À utiliser sur un réseau de confiance.
