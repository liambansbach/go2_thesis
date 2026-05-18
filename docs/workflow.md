# Workflow

This document describes how to use the `go2_thesis` ROS 2 Docker workflow.

## Basic rule

Use the host for:

```text
editing files
Git operations
Docker start/stop/build
network interface setup
NVIDIA driver checks
```

Use the container for:

```text
ROS 2 commands
colcon build
rviz2
rosbag record/play
ros2 topic/node/service commands
running ROS 2 nodes
```

## Start the container

From the host:

```bash
cd ~/Desktop/projects/go2_thesis
./scripts/run.sh
```

This starts the container and opens a shell inside it.

## Open another container shell

From another host terminal:

```bash
cd ~/Desktop/projects/go2_thesis
./scripts/shell.sh
```

Use this when multiple terminals are needed, e.g. one for `rviz2`, one for `ros2 topic echo`, one for a node.

## Stop the container

From the host:

```bash
cd ~/Desktop/projects/go2_thesis
./scripts/stop.sh
```

Stopping the container does not delete project files. The project directory is mounted from the host. Its just stops the container and all processes inside it.

## Rebuild the Docker image

Use this only after changing Docker-related files or installed dependencies:

```bash
./scripts/build.sh
```

Rebuild when changing:

```text
docker/Dockerfile.humble
docker/docker-compose.yaml
docker/ros_entrypoint.sh
system dependencies
pip dependencies
```

Do not rebuild the Docker image for normal Python source-code edits.

## Build the ROS 2 workspace

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

Build the workspace after:

```text
creating a new ROS 2 package
changing package.xml
changing setup.py
adding launch files
adding entry points
changing message/service/action definitions
```

For simple Python code edits, `--symlink-install` often avoids a rebuild. If a node is already running, restart the node.

## Clean rebuild the ROS 2 workspace

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
rm -rf build install log
colcon build --symlink-install
source install/setup.bash
```

Use this if package discovery or builds behave strangely.

## Run ROS 2 checks

Inside the container:

```bash
echo $ROS_DISTRO
echo $RMW_IMPLEMENTATION
which ros2
ros2 topic list
ros2 node list
```

Expected base setup:

```text
ROS_DISTRO=humble
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
```

## Test ROS 2 locally

Terminal 1, inside container:

```bash
ros2 run demo_nodes_cpp talker
```

Terminal 2, inside another container shell:

```bash
ros2 run demo_nodes_py listener
```

## Connect to the Go2 read-only

On the host, check interfaces:

```bash
ip -br link
```

Example:

```text
lo       UNKNOWN
eno1     DOWN
wlo1     UP
docker0  DOWN
```

Use the wired Ethernet interface. In this example, use `eno1`.

On the host:

```bash
./scripts/setup_go2_ethernet.sh eno1
ROS_NET_IFACE=eno1 ./scripts/run.sh
```

Inside the container:

```bash
./scripts/robot_net_check.sh
ros2 topic list
```

At this stage, only read topics. Do not publish motion commands.

## Inspect Go2 topics

Inside the container:

```bash
ros2 topic list
ros2 topic info <topic_name>
ros2 topic echo <topic_name> --once
```

Document useful topics in:

```text
docs/go2_topics.md
config/go2/topics.yaml
```

## Record a Go2 bag

After the real topic names are known, update:

```text
scripts/record_go2_bag.sh
```

Then record:

```bash
./scripts/record_go2_bag.sh
```

Replay later:

```bash
ros2 bag play bags/<bag_name>
```

## Use RViz

Inside the container:

```bash
rviz2
```

Save useful RViz layouts to:

```text
config/rviz/
```

Start RViz with a saved layout:

```bash
rviz2 -d config/rviz/<file>.rviz
```