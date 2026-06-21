# Scripts

Scripts are grouped by workflow. Use the canonical subfolder paths below for all
commands. Old root-level script paths were intentionally removed to keep the
folder unambiguous.

## Docker

- `docker/build.sh`: Build the Humble Docker image.
- `docker/run.sh`: Start the Docker container and open a shell.
- `docker/shell.sh`: Open another shell in the running container.
- `docker/stop.sh`: Stop the Docker container.

```bash
./scripts/docker/build.sh
./scripts/docker/run.sh
./scripts/docker/shell.sh
./scripts/docker/stop.sh
```

### Docker Start Modes

Use the mode that matches the test.

| Mode | Command | Use for |
| --- | --- | --- |
| Offline / local / no robot network | `./scripts/docker/run.sh` | Building, editing, local ROS commands, bag replay, Nvblox quickstart without the live robot, and tests that do not need live Go2-W topics. |
| Live Go2-W over Ethernet | `ROS_NET_IFACE=<your_ethernet_interface> ./scripts/docker/run.sh` | Live Go2-W topic inspection, recording, and Nvblox/RealSense tests over the robot Ethernet link. |

In offline/local mode, `ROS_NET_IFACE` stays empty and no interface-specific
`CYCLONEDDS_URI` is created.

For live Go2-W work, first identify the host Ethernet interface connected to the
robot:

```bash
ip -br addr
```

If `ip` is not available inside an older container, rebuild the Docker image or
use `ifconfig` as a fallback.

Look for a wired interface such as `eno1`, `enp3s0`, or `eth0`. Configure it if
needed, then start Docker with that same interface:

```bash
./scripts/setup/setup_go2_ethernet.sh <your_ethernet_interface>
ROS_NET_IFACE=<your_ethernet_interface> ./scripts/docker/run.sh
```

Example:

```bash
ROS_NET_IFACE=eno1 ./scripts/docker/run.sh
```

Only set `ROS_NET_IFACE` when the Go2-W is connected over Ethernet, the selected
host interface exists, the interface is up or configured, and it has the
expected Go2 network address, usually `192.168.123.x/24`.

### Why `ROS_NET_IFACE` Matters

CycloneDDS can be restricted to a specific network interface. That is useful for
live robot tests because ROS 2 discovery should happen on the Go2 Ethernet
network, not Wi-Fi, Docker bridge networking, or another interface. If the
interface is wrong, disconnected, or not configured, ROS 2 node creation can
fail. Do not set `ROS_NET_IFACE` for offline tests.

New container shells automatically source ROS Humble, the Unitree CycloneDDS
workspace, the Unitree example overlay if it has been built, and the local
`ros2_ws` overlay if it has been built. Manual sourcing is normally no longer
needed in fresh shells. After building `ros2_ws` for the first time, open a new
container shell or run:

```bash
source /workspaces/go2_thesis/ros2_ws/install/setup.bash
```

Verify the shell environment with:

```bash
echo $ROS_DISTRO
echo $RMW_IMPLEMENTATION
echo $ROS_DOMAIN_ID
echo $ROS_NET_IFACE
echo $CYCLONEDDS_URI
which ros2
ros2 topic list
```

Expected:

- Offline/local mode: `ROS_NET_IFACE` is empty, `CYCLONEDDS_URI` is usually
  empty, and `ros2 topic list` runs without CycloneDDS interface errors.
- Live robot mode: `ROS_NET_IFACE` shows the selected interface,
  `CYCLONEDDS_URI` contains that interface name, and `ros2 topic list` shows
  Go2-W topics once the robot and network are reachable.

Troubleshooting:

```text
<iface>: does not match an available interface
rmw_create_node: failed to create domain
```

This usually means the interface passed through `ROS_NET_IFACE` is not usable in
the container. Common causes are a disconnected Ethernet cable or robot, the
wrong interface name, no IP address, an interface not configured for the Go2
network, or setting `ROS_NET_IFACE` for an offline test.

For offline/local work, restart without `ROS_NET_IFACE`:

```bash
./scripts/docker/stop.sh
./scripts/docker/run.sh
```

For live robot work, check and configure the host interface first:

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <your_ethernet_interface>
ROS_NET_IFACE=<your_ethernet_interface> ./scripts/docker/run.sh
```

## Setup

- `setup/setup_go2_ethernet.sh`: Configure the host Ethernet interface for Go2 access.
- `setup/check_nvblox_setup.sh`: Check ROS, NVIDIA, Nvblox, Isaac ROS, and RealSense package setup.
- `setup/download_nvblox_assets.sh`: Download official Nvblox quickstart assets when needed.
- `setup/build_ros2_ws.sh`: Build the local ROS 2 workspace.
- `setup/build_unitree_ros2_packages.sh`: Build Unitree ROS 2 example packages.

```bash
./scripts/setup/setup_go2_ethernet.sh eno1
./scripts/setup/check_nvblox_setup.sh
./scripts/setup/build_ros2_ws.sh
./scripts/setup/build_unitree_ros2_packages.sh
```

## Inspect

- `inspect/inspect_ros_domains.sh`: Read-only scan of ROS_DOMAIN_ID 0 and 10 into `docs/go2_runtime/domain_scan_<timestamp>/`.
- `inspect/inspect_realsense_topics.sh`: Inspect RealSense topics, headers, front-mount TF, and optical-frame connectivity.
- `inspect/inspect_go2w_nvblox_topics.sh`: Optional Nvblox/system state capture after Nvblox is running.
- `inspect/inspect_bag_topic_counts.sh`: Print sqlite3 rosbag topic names, types, and message counts, including zero-count topics.
- `inspect/robot_net_check.sh`: Check Go2 network and ROS 2 visibility.

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_ros_domains.sh
./scripts/inspect/inspect_realsense_topics.sh
./scripts/inspect/inspect_go2w_nvblox_topics.sh
./scripts/inspect/inspect_bag_topic_counts.sh bags/<bag_dir>
```

### LiDAR point cloud orientation debugging

Build and source the workspace, play the bag, launch `go2w_tf.launch.py`, and
open RViz. First set RViz Fixed Frame to `utlidar_lidar` and view
`/utlidar/cloud` directly. In the current offline bag, `/utlidar/cloud` is the
only populated LiDAR point cloud topic; `/utlidar/cloud_base` and
`/utlidar/cloud_deskewed` may exist but can have Count 0.

Until the real `base_link -> utlidar_lidar` extrinsic is calibrated or verified from
a trusted source, do not publish a guessed fixed transform for it. Treat
`utlidar_lidar` as the raw `PointCloud2` frame and view `/utlidar/cloud` with
RViz Fixed Frame set to `utlidar_lidar`. Do not assume the original URDF
`radar` visual link is identical to the raw `PointCloud2` frame. A correct
future dynamic odometry source will provide `odom -> base_link`, but it will not
fix an incorrect `base_link -> utlidar_lidar` sensor transform.

For offline replay/debugging, the TF wrapper can publish the current
experimental `base_link -> utlidar_lidar` visual alignment:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  publish_lidar_tf:=true \
  use_sim_time:=true
```

`publish_lidar_tf:=true` avoids running a separate
`static_transform_publisher` terminal. Its default values are not final
calibration values and must be verified on the real robot or with better data.
A correct future odometry source gives `odom -> base_link`, but does not replace
the need for a correct `base_link -> utlidar_lidar` transform.

Useful checks:

```bash
ros2 topic echo /utlidar/cloud --once --field header
ros2 topic echo /utlidar/lidar_state --once
ros2 topic echo /utlidar/imu --once
ros2 bag info <bag_path>
ros2 run tf2_ros tf2_echo base_link radar
```

`base_link -> radar` comes from the thesis WR Go2-W URDF and should remain
unchanged while the raw `/utlidar/cloud` frame convention is still unverified.

## Record

- `record/record_go2w_bag.sh`: Canonical Go2-W MCAP recorder with profiles `mapping_raw`, `nvblox_debug`, `lidar`, `camera`, `state`, and `full`.

```bash
./scripts/record/record_go2w_bag.sh mapping_raw <label>
./scripts/record/record_go2w_bag.sh nvblox_debug <label>
```

## Go2-W Launch Wrappers

After building and sourcing `ros2_ws`, use:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=false launch_realsense:=false
ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=true launch_realsense:=false
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_nvblox_debug.rviz
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz
ros2 launch go2_bringup go2w_domain_bridge.launch.py
ros2 launch go2_bringup go2w_tf.launch.py publish_robot_description_tf:=true
ros2 launch go2_bringup go2w_tf.launch.py publish_robot_description_tf:=true publish_static_odom_tf:=true
ros2 launch go2_bringup go2w_tf.launch.py publish_robot_description_tf:=true publish_lowstate_joint_states:=true
ros2 launch go2_bringup go2w_tf.launch.py publish_odom_tf:=true odom_topic:=/utlidar/robot_odom
ros2 launch go2_bringup go2w_tf.launch.py publish_front_realsense_tf:=true
```

For offline replay with `ros2 bag play <bag_path> --clock`, launch TF, RViz,
and Nvblox with `use_sim_time:=true`. For the first test, play the bag once
without `--loop`; looping can cause `TF_OLD_DATA` warnings at the loop boundary.

Useful Nvblox replay checks:

```bash
ros2 param get /nvblox_node global_frame
ros2 param get /nvblox_node map_clearing_frame_id
ros2 run tf2_ros tf2_echo base_link front_realsense_base
ros2 run tf2_ros tf2_echo front_realsense_base front_realsense_tilt_axis
ros2 run tf2_ros tf2_echo front_realsense_tilt_axis front_realsense_mount
ros2 run tf2_ros tf2_echo front_realsense_mount front_realsense_body
ros2 run tf2_ros tf2_echo front_realsense_body front_realsense
ros2 run tf2_ros tf2_echo odom base_link
ros2 run tf2_ros tf2_echo base_link front_realsense
ros2 run tf2_ros tf2_echo front_realsense camera_depth_optical_frame
ros2 run tf2_ros tf2_echo front_realsense front_realsense_depth_optical_frame
ros2 run tf2_ros tf2_echo odom camera_depth_optical_frame
```

For the next live test, audit the Jetson RealSense wrapper frame parameters
before changing service files:

```bash
ros2 node list | grep -i camera
RS_NODE=/camera/camera
ros2 param list "$RS_NODE" | grep -Ei "camera_name|camera_namespace|base_frame_id|tf_prefix|publish_tf|tf_publish_rate|frame"
ros2 param get "$RS_NODE" camera_name || true
ros2 param get "$RS_NODE" camera_namespace || true
ros2 param get "$RS_NODE" base_frame_id || true
ros2 param get "$RS_NODE" tf_prefix || true
ros2 param get "$RS_NODE" publish_tf || true
ros2 param get "$RS_NODE" tf_publish_rate || true
```

If the listed camera node is not `/camera/camera`, repeat the same commands
with `RS_NODE=/camera`, `RS_NODE=/front_realsense/camera`,
`RS_NODE=/front/camera`, or the actual node name.

Best final setup: the RealSense driver publishes its internal sensor/optical TF
tree below the thesis frame:

```text
base_link -> ... -> front_realsense -> front_realsense_depth_frame -> front_realsense_depth_optical_frame
```

If a clean parameter combination works, configure the Jetson service rather
than adding aliases in the laptop workspace. If the wrapper only produces
`camera_link` / `camera_depth_optical_frame`, inspect the live TF tree before
adding any compatibility alias.

Live-test hypotheses only, not committed service changes yet:

```bash
ros2 launch realsense2_camera rs_launch.py \
  camera_namespace:=front_realsense \
  camera_name:=front \
  base_frame_id:=realsense \
  publish_tf:=true
```

```bash
ros2 launch realsense2_camera rs_launch.py \
  camera_namespace:=front_realsense \
  camera_name:=front_realsense \
  publish_tf:=true
```

Changing `camera_namespace` or `camera_name` may change topic names, so
`go2w_nvblox.launch.py` topic arguments may need overrides.

Domain 0 is the canonical thesis graph. Domain 10 is an optional
vendor/MyBotShop source graph. Use `go2w_domain_bridge.launch.py` only to bridge
safe read-only topics from Domain 10 into Domain 0. Command/control topics such
as `/cmd_vel`, e-stop, teleop, sport requests, and `/api/.../request` are
intentionally absent from the bridge config.

`go2w_tf.launch.py` is the reproducible TF wrapper for Go2-W replay and
visualization. Use `publish_robot_description_tf:=true` only when vendor `/tf`
and `/tf_static` are not available; do not run the full URDF publisher on top of
bridged vendor TF unless intentionally debugging duplicate child frames. The WR
URDF includes:

- `base_link` to `front_realsense_base` to `front_realsense_tilt_axis` to `front_realsense_mount` to `front_realsense_body` to `front_realsense`
- `base_link -> radar`

The front RealSense names describe the custom thesis mount.
`front_realsense_pitch_joint` in the URDF and `front_realsense_pitch` in
`go2w_tf.launch.py` are the one place to tune camera pitch about the flange
axis. `front_realsense_body` holds the currently installed D456 body visual;
`front_realsense` is the canonical RealSense depth-origin / left-imager frame.
The frame names also fit a future D435i or another RealSense on the same
physical mount after the model-specific body-to-sensor offset and visual mesh
are updated. Do not treat the vendor `camera_link` as this mount. RealSense
optical frames should normally come from the RealSense driver.

`base_link -> radar` is copied from the original Unitree Go2-W URDF. Do not treat the
`radar` visual/sensor link as verified equivalent to `/utlidar/cloud`, whose
`frame_id` is `utlidar_lidar`.

The editable thesis/replay URDF now lives at
`ros2_ws/src/go2w_description/urdf/go2w_description_wr.urdf`. The older
root-level duplicate description tree has been removed; use the ROS package
under `ros2_ws/src/go2w_description` for edits that should build and install.
RobotModel in RViz requires `go2w_description` so mesh paths such as
`package://go2w_description/dae/base.dae` resolve correctly.

RViz profiles live in `ros2_ws/src/go2_bringup/rviz/` and are installed through
`go2_bringup`. CycloneDDS interface config is generated dynamically by
`docker/ros_entrypoint.sh` when `ROS_NET_IFACE` is set.

Use `publish_front_realsense_tf:=true` as the clean complement when bridged
vendor TF lacks the custom front RealSense mount. It publishes only
`base_link` to `front_realsense_base` to `front_realsense_tilt_axis` to `front_realsense_mount` to `front_realsense_body` to `front_realsense`
and does not publish flange visual frames, `camera_link`, or optical frames. If
the RealSense driver still publishes `camera_depth_optical_frame` below
`camera_link`, inspect the real TF tree before adding any alias.

`publish_static_odom_tf:=true` publishes a fake static identity transform from
`odom_frame` to `base_frame`, defaulting to `odom -> base_link`. Use it only for
offline bag, RViz, and Nvblox sanity checks where the robot is treated as fixed.
It is not valid for real moving-map evaluation. Real Nvblox mapping still needs
a real dynamic transform such as `odom -> base_link`, usually from odometry or SLAM.

`publish_odom_tf:=true` enables the read-only `nav_msgs/Odometry` to TF bridge.
Use it only when the selected odometry topic contains a usable dynamic pose, for
example:

```bash
ros2 launch go2_bringup go2w_tf.launch.py publish_odom_tf:=true odom_topic:=/utlidar/robot_odom
```

`publish_lowstate_joint_states:=true` starts a read-only LowState to
`/joint_states` visualization bridge. It requires the Unitree ROS 2 message
overlay to be built and sourced so `unitree_go/msg/LowState` is available. The
default motor-to-joint order is unverified on the real Go2-W; confirm or
override the `joint_names` parameter before using it for accurate visualization
or kinematics. LowState only moves the movable joints through `/joint_states`;
the robot will not move through the world without a real dynamic `odom -> base_link`.

### Offline Replay TF Check

Build and source the local ROS 2 workspace:

```bash
./scripts/setup/build_ros2_ws.sh
source /workspaces/go2_thesis/ros2_ws/install/setup.bash
```

In one shell, play the bag with simulated time. Prefer a single pass for TF
validation:

```bash
ros2 bag play <bag_path> --clock
```

Older Go2-W bags may contain legacy `/tf`, `/tf_static`, and
`/robot_description` data with frames such as `odom -> base`, `base -> rs_base`,
`rs_tilt_axis`, `rs_mount`, `rs_d456_solid`, and `camera_link`. Do not replay
those old TF or robot-description topics while testing the current
`base_link`/`front_realsense` URDF tree; RViz will show parallel old and new TF
worlds. To test only the new static robot/RealSense tree, launch
`go2w_tf.launch.py` without bag replay. To use old sensor data with the current
tree, replay only selected sensor topics and avoid old TF/robot-description
topics. Old bags are still useful for qualitative sensor visualization, but
they are not a clean validation of the current `front_realsense` TF
architecture. Do not add a permanent `front_realsense -> camera_link` alias just
to make old bags look clean.

In another shell, launch the static replay TF tree:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  use_sim_time:=true
```

Open the robot/TF RViz profile:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py \
  rviz_config:=go2w_tf_robot_debug.rviz
```

Then inspect the TF tree:

```bash
ros2 run tf2_tools view_frames
```

Verify these paths are present:

- `odom -> base_link`
- `base_link -> radar`
- `base_link` to `front_realsense_base` to `front_realsense_tilt_axis` to `front_realsense_mount` to `front_realsense_body` to `front_realsense` to `camera_depth_frame` to `camera_depth_optical_frame`

`publish_static_odom_tf:=true` makes the robot fixed in the world. This is only
for offline bag/RViz/Nvblox sanity checks and is not valid for moving-map
evaluation. Real Nvblox mapping still requires a real dynamic transform such as
`odom -> base_link`, usually from odometry or SLAM.

When using `ros2 bag play --clock --loop`, RViz or TF tools may warn:

```text
TF_OLD_DATA ignoring data from the past
```

This can happen at the loop boundary because simulated time jumps backwards. Do
not hide this by stamping replay TF with wall time; bag replay and Nvblox should
stay on simulated time. For TF validation, either play the bag once without
`--loop`, or restart RViz and TF publishers after the bag loops.

Verification checklist after launching bag playback and the TF wrapper:

```bash
ros2 pkg prefix go2w_description
ros2 topic echo /robot_description --once
ros2 topic echo /joint_states --once
ros2 run tf2_ros tf2_echo odom base_link
ros2 run tf2_ros tf2_echo base_link front_realsense
ros2 run tf2_ros tf2_echo front_realsense camera_depth_optical_frame
ros2 run tf2_ros tf2_echo front_realsense front_realsense_depth_optical_frame
ros2 run tf2_ros tf2_echo odom camera_depth_optical_frame
ros2 run tf2_tools view_frames
```

Expected TF paths:

- `odom -> base_link`
- `base_link -> radar`
- `base_link` to `front_realsense_base` to `front_realsense_tilt_axis` to `front_realsense_mount` to `front_realsense_body` to `front_realsense` to `camera_depth_frame` to `camera_depth_optical_frame`

Leg and wheel transforms require `/joint_states`. If
`publish_lowstate_joint_states:=true` is disabled or `/lowstate` is absent in
the bag, fixed sensor frames can still work, but movable joints will stay at the
robot_state_publisher default positions.
