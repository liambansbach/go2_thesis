# Go2-W Thesis Workspace

ROS 2/Docker workspace for Unitree Go2-W sensor inspection, live RViz
visualization, bag recording/replay, and mapping feasibility experiments. This
repository is read-only with respect to robot motion: do not add launch files or
scripts that publish command/control topics.

## Quick Start

```bash
./scripts/docker/build.sh
./scripts/docker/run.sh
```

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

For live Go2-W Ethernet work, configure the host interface first, then pass it
into Docker:

```bash
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

Use `./scripts/docker/run.sh` without `ROS_NET_IFACE` for offline builds, bag
replay, and local checks.

## Main Docs

- `docs/setup.md`: first-time host, Docker, GPU, and workspace setup.
- `docs/workflow.md`: daily live visualization, replay, recording, inspection,
  and optional Nvblox commands.
- `docs/go2w_current_sensor_graph_status.md`: current known robot/sensor graph
  status and mapping conclusion.
- `docs/code_overview.md`: where to change what.
- `docs/jetson_information.md`: private robot-specific onboard reference.
- `scripts/README_scripts.md`: script reference.

## Project Layout

```text
docker/                         Docker image, compose file, ROS entrypoint
scripts/                        Workflow helpers
docs/                           Setup, workflow, status, and code notes
ros2_ws/src/go2_bringup/        Go2-W launch files, TF helpers, RViz profiles
ros2_ws/src/vendor/mybotshop/go2_description/
                                Unmodified MYBOTSHOP base package and meshes
ros2_ws/src/hexlab_go2w_description/
                                Current HEXLab Go2-W robot description for ROS/RViz/Jetson visualization
ros2_ws/src/hexlab_go2w_bringup/
                                Future live Jetson/domain-10 state bringup package
ros2_ws/src/go2w_description/   Legacy/reference only, ignored by colcon
ros2_ws/src/semantic_risk_node/ Future semantic perception package
ros2_ws/src/risk_map_projection/ Future risk projection package
bags/                           Local rosbag data, ignored/generated
third_party/                    External source trees
requirements/                   Python requirement files
```
