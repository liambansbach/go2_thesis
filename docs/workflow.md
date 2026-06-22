# Daily Workflow

Compact command sheet for normal Go2-W thesis work. Use `docs/setup.md` for
first-time setup, `docs/go2w_current_sensor_graph_status.md` for the current
robot/sensor status, and `scripts/README_scripts.md` for script descriptions.

This repository should stay read-only with respect to robot motion. Do not
publish `/cmd_vel`, sport requests, e-stop commands, teleop commands, or
robot-state-changing API requests from this workspace.

## Start Docker

Offline builds, bag replay, and local checks:

```bash
./scripts/docker/run.sh
```

Live Go2-W Ethernet work:

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

`<iface>` is the wired host interface connected to the Go2-W, for example
`eno1`, `enp3s0`, or `eth0`.

Open another container shell or stop the container:

```bash
./scripts/docker/shell.sh
./scripts/docker/stop.sh
```

## Build

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build
source install/setup.bash
```

## Live RViz demo on the robot

1. On the host, configure Ethernet and start Docker:

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

2. In the container, confirm the ROS graph:

```bash
echo "$ROS_DISTRO"
echo "$RMW_IMPLEMENTATION"
echo "$ROS_DOMAIN_ID"
ros2 topic list
./scripts/inspect/inspect_ros_domains.sh
```

Domain 0 is the canonical thesis graph. Keep this workflow read-only: no
`/cmd_vel`, no e-stop, no sport requests, and no command/control topics.

3. Prefer the clean `/front_realsense` service mode when it is active on the
Jetson:

```bash
CAMERA_NS=/front_realsense ./scripts/inspect/inspect_realsense_topics.sh
```

Use the legacy/current `/camera` fallback when the robot is still running the
older service:

```bash
./scripts/inspect/inspect_realsense_topics.sh
```

4. Terminal A: choose one visualization mode.

### Self-contained local visualization mode

Recommended quick supervisor demo mode. Use this when not relying on bridged
Domain 10 vendor TF, RobotDescription, or JointStates.

Preferred `/front_realsense` service:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  publish_lidar_tf:=true \
  publish_realsense_camera_link_alias:=false \
  use_sim_time:=false
```

Legacy `/camera` service:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  publish_lidar_tf:=true \
  publish_realsense_camera_link_alias:=true \
  use_sim_time:=false
```

`publish_static_odom_tf:=true` is fake static odom for standing RViz/demo use
only. Do not use it for moving-map evaluation.

`publish_lidar_tf:=true` is experimental visual alignment for `/utlidar/cloud`,
not final LiDAR calibration.

`publish_realsense_camera_link_alias:=true` is only for legacy single-camera
`/camera` services using `camera_name:=camera`. Keep it false for the preferred
`/front_realsense` service.

### Domain 10 bridge visualization mode

Use this when Domain 10 provides useful vendor TF, RobotDescription, and
JointStates. Start the read-only bridge:

```bash
ros2 launch go2_bringup go2w_domain_bridge.launch.py
```

The bridge intentionally excludes command, request, teleop, e-stop, and other
robot-state-changing topics.

Do not run `publish_robot_description_tf:=true` on top of bridged vendor TF.
Use `publish_front_realsense_tf:=true` only if the bridged vendor TF lacks the
custom front RealSense mount:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_front_realsense_tf:=true \
  use_sim_time:=false
```

Use `publish_static_odom_tf:=true` only if no real `odom -> base_link` exists
and the robot is standing/static:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_front_realsense_tf:=true \
  publish_static_odom_tf:=true \
  use_sim_time:=false
```

5. Terminal B: open RViz.

Preferred `/front_realsense` profile:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py \
  rviz_config:=go2w_tf_robot_debug_front_realsense.rviz
```

Legacy `/camera` fallback profile:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py \
  rviz_config:=go2w_tf_robot_debug.rviz
```

## Inspect

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_ros_domains.sh
./scripts/inspect/inspect_realsense_topics.sh
CAMERA_NS=/front_realsense ./scripts/inspect/inspect_realsense_topics.sh
./scripts/inspect/inspect_bag_topic_counts.sh bags/<bag_dir>
```

Inspection outputs are generated under `docs/go2_runtime/` and are ignored by
git. Move only durable conclusions into
`docs/go2w_current_sensor_graph_status.md`.

Useful TF checks:

```bash
ros2 run tf2_ros tf2_echo odom base_link
ros2 run tf2_ros tf2_echo base_link front_realsense
ros2 run tf2_ros tf2_echo front_realsense camera_depth_optical_frame
ros2 run tf2_ros tf2_echo front_realsense front_realsense_depth_optical_frame
ros2 run tf2_tools view_frames
```

Root-level `frames*.gv` and `frames*.pdf` outputs from `view_frames` are
generated files and are ignored.

## Record Bags

Use the canonical recorder:

```bash
./scripts/record/record_go2w_bag.sh mapping_raw <label>
./scripts/record/record_go2w_bag.sh nvblox_debug <label>
```

The recorder writes a small `recording_summary.txt` inside each bag directory.
Do not modify existing bag data during inspection or cleanup.

## Replay Bags

Check bag topic counts before relying on a replay:

```bash
./scripts/inspect/inspect_bag_topic_counts.sh bags/<bag_dir>
```

Replay with simulated time:

```bash
ros2 bag play bags/<bag_dir> --clock
```

Older Go2-W bags may contain legacy `/tf`, `/tf_static`, and
`/robot_description` data with frames such as `odom -> base`, `base -> rs_base`,
`rs_tilt_axis`, `rs_mount`, `rs_d456_solid`, and `camera_link`. Do not replay
those old TF or robot-description topics while testing the current
`base_link`/`front_realsense` tree. To use old sensor data with the current
tree, replay only selected sensor topics and avoid old TF/robot-description
topics. Old bags are still useful for qualitative sensor visualization, but
they are not clean validation of the current front RealSense TF architecture.

For offline replay TF/RViz checks:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  use_sim_time:=true
```

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py \
  rviz_config:=go2w_tf_robot_debug.rviz \
  use_sim_time:=true
```

Prefer one bag pass for TF validation. Looping simulated time can produce
`TF_OLD_DATA` warnings when the clock jumps backward.

## Optional Nvblox

Nvblox is no longer a hard thesis dependency while no stable dynamic
`odom -> base_link` source exists. Keep it as an optional static feasibility or
demo path only.

The launch consumes existing RealSense topics from the Jetson service, a bag, or
another explicitly started source. `launch_realsense:=false` is kept for
compatibility/documentation; `go2w_nvblox.launch.py` does not start a local
RealSense driver.

Legacy/current `/camera` topic mode:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=false \
  launch_realsense:=false \
  camera_namespace:=/camera \
  global_frame:=odom \
  map_clearing_frame_id:=base_link \
  voxel_size:=0.08 \
  enable_lidar:=false
```

Clean `/front_realsense` service mode:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=false \
  launch_realsense:=false \
  camera_namespace:=/front_realsense \
  global_frame:=odom \
  map_clearing_frame_id:=base_link \
  voxel_size:=0.08 \
  enable_lidar:=false
```

If only one stream has a non-standard name, override the explicit topic argument
instead, for example `depth_image_topic:=/some/depth/topic`.

Optional Nvblox/system scan after the node is running:

```bash
./scripts/inspect/inspect_go2w_nvblox_topics.sh
```
