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
| `stageir_sim/` | Paquet ROS : launch, objets à saisir, réglages attendus par le client |

## Installation

Il faut un PC Linux avec **Docker** et un affichage graphique (pour la fenêtre Gazebo).

```bash
git clone https://github.com/SkyfrostFR/RechercheGazeboServeur.git
cd RechercheGazeboServeur
docker build -t stageir/tiago-dual-noetic:latest .
```

## Lancer

```bash
./run_sim.sh               # avec la fenêtre Gazebo
GUI=false ./run_sim.sh     # sans fenêtre
```

Arrêt : `docker stop tiago_dual_noetic`.

Le client se connecte ensuite à `ws://<adresse IP de ce PC>:9090`.

Attention : rosbridge n'a pas d'authentification. À utiliser sur un réseau de confiance.
