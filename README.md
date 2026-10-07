# GazeboRobotServer — serveur Gazebo du jumeau TIAGo Dual

Côté **serveur** de l'architecture client / serveur du jumeau numérique TIAGo Dual
(TIAGo++). Le client Unity (VR, Quest 3) est le dépôt
[GazeboRobotClient](https://github.com/SkyfrostFR/GazeboRobotClient).

```
 ┌──────── client (GazeboRobotClient) ────────┐        ┌──────── serveur (ce dépôt) ────────┐
 │ Unity · scène TiagoClient · ROS#           │  WS    │ Docker · ROS 1 Noetic              │
 │ jumeau, IK, VR, pinces, conduite de base   │ ─────► │ rosbridge :9090                    │
 │ StreamingAssets/twin_server.json           │        │ Gazebo Classic · TIAGo Dual public │
 └────────────────────────────────────────────┘        │ table + objets à saisir            │
                                                       └────────────────────────────────────┘
```

## Contenu

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Image ROS 1 Noetic avec la simulation publique PAL du TIAGo Dual et rosbridge |
| `run_sim.sh` | Lance la simulation dans Docker (réseau hôte, rosbridge sur `0.0.0.0:9090`) |
| `stageir_sim/launch/sim.launch` | Gazebo + rosbridge + contrôleurs, adaptés à ce qu'attend le jumeau Unity |
| `stageir_sim/config/objects.yaml` | Table et objets à saisir (aussi lus par le client via rosapi) |
| `stageir_sim/scripts/spawn_objects.py` | Crée ces objets dans Gazebo |
| `stageir_sim/scripts/set_torso.py` | Met le torse à la hauteur du jumeau Unity (0,20 m) |
| `stageir_sim/scripts/depth_to_mm.py` | Profondeur au format du vrai robot (16UC1, mm) |
| `scripts/twin_probe.sh` | Test auto : synchro des deux bras Unity ↔ Gazebo |
| `scripts/twin_world_probe.sh` | Test auto : objets, conduite de la base, saisie d'un cylindre |

## Installation

Docker est nécessaire, et un serveur X pour l'interface Gazebo (le conteneur tourne avec
l'uid de l'utilisateur : XWayland refuse root).

```bash
docker build -t stageir/tiago-dual-noetic:latest .
```

## Lancer

```bash
./run_sim.sh                  # interface Gazebo visible
GUI=false ./run_sim.sh        # sans interface
WORLD=small_office ./run_sim.sh
```

Arrêt : `docker stop tiago_dual_noetic`. Depuis StageIR, `pixi run ros1-build` et
`pixi run ros1-sim` font la même chose.

Au démarrage, la simulation :
- ouvre rosbridge sur le port 9090 ; c'est l'adresse à mettre dans le
  `twin_server.json` du client ;
- charge les contrôleurs de vitesse des bras (arrêtés ; le client bascule entre position
  et vitesse avec `switch_controller`) ;
- règle le torse à 0,20 m : le jumeau Unity n'a pas d'articulation de torse et son buste
  est fixé à cette hauteur. À torse 0, les bras Gazebo seraient 16 cm plus bas que dans
  Unity. Option `torso:=...` de `sim.launch` ;
- crée la table et les objets de `objects.yaml` (option `objects:=false` pour s'en passer).

## Tests automatiques

Ils compilent le client en build Linux puis le lancent sans casque. Ils supposent le
client cloné à côté (`StageIR/ros1` et `StageIR/unity/TiagoClient`), ou
`TWIN_CLIENT=<chemin du client>`. Unity 6000.6.3 est attendu dans
`~/Unity/Hub/Editor/6000.6.3f1` (sinon `UNITY_EDITOR=<binaire Unity>`).

```bash
./scripts/twin_probe.sh          # bras : Unity -> Gazebo et Gazebo -> Unity
./scripts/twin_world_probe.sh    # sur une simulation fraîche : base + saisie
```

`SKIP_BUILD=1` réutilise la dernière build. Résultats du 2026-10-06 :
- bras : écart max 1,3° en mouvement, 0,2° à l'arrêt, 0,00° Gazebo → Unity ;
- base : Unity = Gazebo à 0,0 cm / 0,0° ;
- saisie : cylindre rouge soulevé de 9,6 cm.

## À savoir

- rosbridge n'a pas d'authentification : tout appareil qui joint le port 9090 peut
  commander le robot. À réserver à un réseau de confiance.
- Pas de runtime NVIDIA dans le conteneur : Gazebo fait son rendu en logiciel (Mesa
  llvmpipe).
- `pal_msgs` est figé sur `b843390cbf` : la version suivante a retiré
  `pal_navigation_msgs`, qui n'a pas de dépôt public.
- Les nœuds ROS s'annoncent en `localhost` : un changement de DNS ou de VPN ne casse pas
  `switch_controller`. Seul rosbridge est exposé sur le réseau.
- Dans la simulation, la commande `/parallel_gripper_<côté>_controller/command` n'agit
  pas : le client ferme les pinces avec le service `.../grasp`.
