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
echo $ROS_DOMAIN_ID
which ros2
ros2 topic list
```

For live robot visibility:

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_ros_domains.sh
./scripts/inspect/inspect_realsense_topics.sh
```

Only read topics from the robot; this repository should not publish motion commands.

Use `ROS_DOMAIN_ID=0` as the canonical thesis graph. If vendor/MyBotShop data is
only visible on Domain 10, bridge the safe read-only topics into Domain 0:

```bash
ros2 launch go2_bringup go2w_domain_bridge.launch.py
```

The bridge intentionally excludes command, request, e-stop, and teleop topics.

## Record Bags

```bash
./scripts/record/record_go2w_bag.sh mapping_raw <label>
./scripts/record/record_go2w_bag.sh nvblox_debug <label>
```

Replay:

```bash
ros2 bag play bags/<bag_name>
./scripts/inspect/inspect_bag_topic_counts.sh bags/<bag_name>
```

## RViz

RViz profiles live in `ros2_ws/src/go2_bringup/rviz/` and are installed through `go2_bringup`:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_nvblox_debug.rviz
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz
```

## Nvblox

Use `docs/go2w_nvblox_live_test.md` for the canonical live and replay procedure.

Current canonical defaults:

```text
global_frame: odom
map_clearing_frame_id: base_link
launch_realsense: false
enable_lidar: false
front RealSense TF: base_link to front_realsense_base to front_realsense_tilt_axis to front_realsense_mount to front_realsense_body to front_realsense
```

The vendor `camera_link` is not assumed to be the custom front RealSense mount.
`front_realsense_pitch_joint` / `front_realsense_pitch` is the one place to tune
camera pitch. `front_realsense_body` is the D456 body visual helper, and
`front_realsense` is the canonical RealSense depth-origin / left-imager frame.
RealSense optical frames should come from the RealSense driver. If the driver
still publishes `camera_depth_optical_frame` below `camera_link`, inspect the
real TF tree before adding any alias.

Optional Nvblox/system scan after Nvblox is running:

```bash
./scripts/inspect/inspect_go2w_nvblox_topics.sh
```
