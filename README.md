# Go2-W Semantic Mapping

ROS 2/Docker workspace for Unitree Go2-W sensor access, Nvblox feasibility testing, and semantic risk-map projection experiments.

Target stack:
- Host: Ubuntu 24.04
- Container: Ubuntu 22.04 + ROS 2 Humble
- Middleware: CycloneDDS
- Robot: Unitree Go2-W
- Mapping: Intel RealSense D456, Unitree 4D LiDAR, Isaac ROS Nvblox, and later semantic/risk-map projection

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

For live Go2-W Ethernet work, configure the host interface first, then pass it into Docker:

```bash
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

Use `./scripts/docker/run.sh` without `ROS_NET_IFACE` for offline builds, bag replay, and local Nvblox checks.

## Main Docs

- `docs/setup.md`: first-time host, Docker, GPU, and workspace setup.
- `docs/workflow.md`: compact daily workflow cheat sheet.
- `scripts/README_scripts.md`: detailed script and launch-wrapper reference.
- `docs/go2w_nvblox_live_test.md`: detailed Go2-W RealSense/Nvblox live-test guide.
- `docs/code_overview.md`: where to change what.

## Project Layout

```text
docker/                         Docker image, compose file, ROS entrypoint
scripts/                        Workflow helpers
docs/                           Setup, workflow, live-test, and reference docs
ros2_ws/src/go2_bringup/        Go2-W launch files, TF helpers, RViz profiles, Nvblox config
ros2_ws/src/go2w_description/   Canonical editable Go2-W URDF, meshes, and joint config
ros2_ws/src/semantic_risk_node/ Future semantic perception package
ros2_ws/src/risk_map_projection/ Future risk projection package
bags/                           Local rosbag data, ignored/generated
third_party/                    External source trees
requirements/                   Python requirement files
```
