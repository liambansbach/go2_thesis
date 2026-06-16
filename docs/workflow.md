# Daily Workflow

Compact command sheet for normal Go2-W development. See `docs/setup.md` for first-time setup, `scripts/README_scripts.md` for script details, and `docs/go2w_nvblox_live_test.md` for Nvblox setup notes and the full live procedure.

## Start Container

Offline/local work:

```bash
./scripts/docker/run.sh
```

Live Go2-W Ethernet work:

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

-> iface is the Ethernet interface connected to the Go2-W, e.g., `eno1` or `enp0s3`...

Open a second shell:

```bash
./scripts/docker/shell.sh
```

Stop the container:

```bash
./scripts/docker/stop.sh
```

## Build Workspace

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build
source install/setup.bash
```

## Basic Checks

```bash
echo $ROS_DISTRO
echo $RMW_IMPLEMENTATION
which ros2
ros2 topic list
```

For live robot visibility:

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_go2w_topics.sh
```

Only read topics from the robot; this repository should not publish motion commands.

## Record Bags

```bash
./scripts/record/record_go2w_bag.sh mapping_raw <label>
./scripts/record/record_go2w_bag.sh nvblox_debug <label>
```

Replay:

```bash
ros2 bag play bags/<bag_name>
```

## RViz

RViz profiles live in `ros2_ws/src/go2_bringup/rviz/` and are installed through `go2_bringup`:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_nvblox_debug.rviz
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz
```

## Nvblox

Use `docs/go2w_nvblox_live_test.md` for Nvblox setup checks, local quickstart notes, and the detailed Go2-W live-test flow.
