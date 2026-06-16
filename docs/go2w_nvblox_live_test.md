# Go2-W Nvblox Live Test

This guide is for static-scene Go2-W Nvblox feasibility tests with a front-mounted Intel RealSense D456. The robot may be moved manually with the remote controller, but this repository must not publish motion commands, start autonomous navigation, or change robot state.

Keep the stack on Ubuntu 22.04, ROS 2 Humble, and Isaac ROS release-3.x. Start with RealSense depth-only/static TSDF behavior, then evaluate optional LiDAR fusion separately after the camera-only result is understood. Do not enable human, dynamic, or segmentation Nvblox pipelines for this harness.

## Nvblox Setup Notes

Before live testing, check the local container setup:

```bash
./scripts/setup/check_nvblox_setup.sh
```

This checks ROS, CycloneDDS, NVIDIA runtime visibility, installed Nvblox/Isaac/RealSense packages, and available Nvblox RealSense example arguments when present.

The official Nvblox quickstart assets are not committed with this repository. Download them only when needed:

```bash
./scripts/setup/download_nvblox_assets.sh
```

Run the official Isaac ROS Nvblox quickstart manually:

```bash
ros2 launch nvblox_examples_bringup isaac_sim_example.launch.py \
  rosbag:=/workspaces/go2_thesis/bags/isaac_ros_assets/isaac_ros_nvblox/quickstart \
  navigation:=False
```

That quickstart checks Nvblox, GPU, and RViz at a basic level. It does not validate the Go2-W RealSense mount, Go2-W TF, or robot odometry.

## 1. Preflight

The real thesis setup is an Ethernet topic-consumer setup:

- The D456 is connected onboard to the Go2-W Jetson/onboard computer, not to the laptop.
- The laptop connects to the Go2-W over Ethernet.
- The laptop Docker container should normally consume existing `/camera/...`, `/utlidar/...`, odometry, and TF topics over DDS.
- The custom onboard RealSense service should already publish RealSense topics in `ROS_DOMAIN_ID=0`.
- Do not run the laptop/container RealSense launch during normal live robot tests.

On the host:

```bash
cd ~/Desktop/projects/go2_thesis
git status --short
ip -br addr
nvidia-smi
```

Create a live-test log folder before launching anything:

```bash
./scripts/inspect/start_go2w_live_test_log.sh static_standing_01
```

## 2. Ethernet Setup

Use the wired interface connected to the Go2-W. For the full Docker networking
explanation and offline/local mode, see `scripts/README_scripts.md`.

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

Only pass `ROS_NET_IFACE` when the robot is connected over Ethernet and the
selected host interface exists, is configured, and has the expected Go2 network
address, usually `192.168.123.x/24`. If you are replaying bags or running local
Nvblox tests without the live robot, start with `./scripts/docker/run.sh`
instead.

Inside the container:

```bash
echo "$ROS_DISTRO"
echo "$RMW_IMPLEMENTATION"
echo "$ROS_NET_IFACE"
echo "$CYCLONEDDS_URI"
./scripts/inspect/robot_net_check.sh
```

Expected stack: Ubuntu 22.04 container, ROS 2 Humble, CycloneDDS.

## 3. RealSense Health Check

For normal live Go2-W tests, do not launch a local RealSense driver. Confirm that the onboard service is already publishing camera topics over DDS:

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_realsense_topics.sh
ros2 topic list -t | grep -E "/camera|/utlidar|/odom|/tf"
ros2 topic hz /camera/depth/image_rect_raw
ros2 topic hz /camera/color/image_raw
ros2 topic echo /camera/depth/camera_info --once
```

If the onboard service uses a different camera namespace, use the visible `/camera/...` topic names from `ros2 topic list -t` and `docs/reference/topics/go2w_topics.yaml`.

Open the robot/TF RViz profile after camera topics are visible:

```bash
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz
```

Do not launch a laptop/container RealSense driver during normal live Go2-W tests. The RealSense is expected to be published by the onboard Jetson service.

Optional onboard checks, without writing passwords into docs:

```bash
ssh unitree@192.168.123.18
systemctl status go2-realsense-domain0.service --no-pager
ros2 topic list -t | grep camera
```

## 4. Go2-W Topic Health Check

With the Go2-W powered and visible on DDS:

```bash
./scripts/inspect/inspect_go2w_topics.sh
./scripts/inspect/inspect_go2w_nvblox_topics.sh
ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz
```

Confirm the real frame IDs from message headers:

```bash
ros2 topic echo /utlidar/cloud --once
ros2 topic echo /utlidar/robot_odom --once
ros2 run tf2_tools view_frames
```

Use `odom` as the first RViz fixed frame guess, then change it if the real TF tree says otherwise.

## 5. Live RealSense-Only Nvblox

Start with RealSense-only Nvblox. Do not add LiDAR fusion until the camera-only mesh is stable.

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=false \
  launch_realsense:=false \
  global_frame:=odom \
  map_clearing_frame_id:=base \
  voxel_size:=0.08 \
  enable_lidar:=false
```

The wrapper launches the Nvblox component directly for normal Go2-W use, loads the official Nvblox base config followed by `go2_bringup/config/nvblox/go2w_static_realsense.yaml`, sets `mapping_type:=static_tsdf`, enables depth and TF transforms, disables segmentation and topic transforms, and remaps the normal onboard `/camera/...` RealSense topics into Nvblox `camera_0` inputs. It does not launch a laptop/container RealSense driver unless `launch_realsense:=true` is explicitly requested. If the onboard service publishes a different namespace or aligned-depth topics, override the visible launch arguments:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  depth_image_topic:=/camera/camera/depth/image_rect_raw \
  depth_camera_info_topic:=/camera/camera/depth/camera_info \
  color_image_topic:=/camera/camera/color/image_raw \
  color_camera_info_topic:=/camera/camera/color/camera_info
```

Leave `enable_lidar:=false` for the first evaluation. When testing LiDAR later, use `enable_lidar:=true lidar_topic:=/utlidar/cloud`, but verify Unitree 4D LiDAR-specific Nvblox parameters first; do not reuse VLP16/Hesai defaults blindly.

If your installed `nvblox_examples_bringup` does not support `launch_realsense`, inspect the available arguments:

```bash
ros2 launch nvblox_examples_bringup realsense_example.launch.py --show-args
```

The wrapper is best-effort across Isaac ROS Nvblox package versions. It includes this repository's Nvblox RViz debug layout when `use_rviz:=true`.

Only enable the optional `camera0_link` alias for compatibility with Isaac ROS examples or configs that still hard-code that frame:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  publish_camera0_alias_tf:=true
```

This publishes an identity `camera_link -> camera0_link` static transform. It is only a compatibility alias and is not a new physical calibration.

## 6. Static Transform

Only publish a camera-to-base static transform when explicitly testing it:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_camera_tf:=true \
  camera_parent_frame:=base \
  camera_child_frame:=camera_link \
  camera_x:=0.25 camera_y:=0.0 camera_z:=0.18 \
  camera_roll:=0.0 camera_pitch:=0.0 camera_yaw:=0.0
```

Those numbers are placeholders. Measure the D456 mount on the real Go2-W before final evaluation. Bad TFs cause ghosting, doubled walls, and smeared map surfaces.

## 7. Odometry To TF Bridge

Moving Nvblox tests need a dynamic transform such as `odom -> base`. First check whether it already exists:

```bash
ros2 run tf2_ros tf2_echo odom base
```

If that transform is missing, confirm the selected Go2-W odometry topic is really `nav_msgs/msg/Odometry`:

```bash
ros2 topic info /utlidar/robot_odom -v
ros2 topic echo /utlidar/robot_odom --once
```

If the topic type and frame IDs look correct, run the read-only odometry-to-TF bridge:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_odom_tf:=true \
  odom_topic:=/utlidar/robot_odom
```

You can override frames if the message headers are empty or not the names you want:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_odom_tf:=true \
  odom_topic:=/utlidar/robot_odom \
  odom_parent_frame:=odom \
  odom_child_frame:=base
```

After also launching the measured camera static transform, re-check the full transform chain:

```bash
ros2 run tf2_ros tf2_echo odom camera_link
```

Use this bridge only for TF publication from odometry pose. It does not publish commands or modify robot state.

## 8. Bag Recording

Use MCAP bags with Go2-W names:

```bash
./scripts/record/record_go2w_bag.sh mapping_raw static_standing_01
./scripts/record/record_go2w_bag.sh nvblox_debug static_standing_01
./scripts/record/record_go2w_bag.sh lidar lidar_only_01
./scripts/record/record_go2w_bag.sh camera camera_only_01
./scripts/record/record_go2w_bag.sh state state_only_01
./scripts/record/record_go2w_bag.sh full full_system_01
```

The script filters requested topics against currently available topics and writes metadata beside each bag folder.

## 9. Test Patterns

Test 1, static standing:

```text
Robot stands still, scene static, 20-30 s. Check mesh stability, TF warnings, and depth frame rate.
```

Test 2, slow straight hallway motion:

```text
Drive slowly forward through a simple hallway. Watch for ghosting, doubled walls, map stretch, lag, or dropped depth frames.
```

Test 3, slow yaw/curve:

```text
Turn slowly in yaw or drive a gentle curve. This exposes camera extrinsic, odometry, and TF timing problems.
```

Test 4, return to mapped area:

```text
Drive out and return through the same area. Look for doubled walls, smeared edges, alignment errors, and mesh or ESDF/map-slice instability.
```

Evaluation notes:

- Record ghosting, doubled walls, smeared edges, TF warnings, sensor dropouts, mesh stability, and ESDF/map-slice stability.
- First score the RealSense-only result. Test LiDAR fusion as a separate follow-up run only after the RealSense baseline is clean.

After each run, save Nvblox outputs and the surrounding ROS state when the services are available:

```bash
./scripts/inspect/save_nvblox_outputs.sh static_standing_01
```

## 10. Replay Workflow

Terminal 1:

```bash
ros2 bag play bags/go2w_<profile>_<label>_<timestamp> --clock
```

For a first offline Nvblox test, play the bag once without `--loop`; looping can cause `TF_OLD_DATA` warnings at the loop boundary when simulated time jumps backwards.

Terminal 2, TF:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_robot_description_tf:=true \
  publish_static_odom_tf:=true \
  publish_lowstate_joint_states:=true \
  use_sim_time:=true
```

Terminal 3, Nvblox and RViz:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=true \
  launch_realsense:=false
```

Keep TF, RViz, and Nvblox on `use_sim_time:=true` for `ros2 bag play --clock`.

## 11. Screenshots And Screen Recording

Capture:

- RViz fixed frame and TF tree.
- RealSense color and aligned depth.
- Nvblox mesh/map output.
- Terminal running `ros2 topic hz` for depth, odometry, and key Nvblox outputs.
- The checklist in `docs/go2_runtime/live_tests/<timestamp>_<label>/checklist.md`.

## Troubleshooting

No RealSense topics:

```bash
./scripts/inspect/robot_net_check.sh
ros2 topic list -t | grep -E "/camera|realsense|depth|color"
ros2 topic hz /camera/depth/image_rect_raw
ros2 topic hz /camera/color/image_raw
```

For normal live tests, first debug DDS/network visibility and the onboard RealSense service. Optional onboard checks:

```bash
ssh unitree@192.168.123.18
systemctl status go2-realsense-domain0.service --no-pager
ros2 topic list -t | grep camera
```

Use `v4l2-ctl --list-devices` only on the Jetson/onboard computer.

No LiDAR topics:

```bash
echo "$ROS_NET_IFACE"
./scripts/inspect/robot_net_check.sh
ros2 topic list -t | grep -i utlidar
```

Check Ethernet interface selection and CycloneDDS.

CycloneDDS interface error:

```text
<iface>: does not match an available interface
rmw_create_node: failed to create domain
```

Restart without `ROS_NET_IFACE` for offline work, or re-check the host Ethernet
interface with `ip -br addr` and `./scripts/setup/setup_go2_ethernet.sh <iface>`
before starting a live robot container.

No TF between camera and odom/base:

```bash
ros2 run tf2_tools view_frames
ros2 run tf2_ros tf2_echo odom base
ros2 run tf2_ros tf2_echo odom camera_link
```

If `odom -> base` is missing but a Go2-W odometry topic is valid `nav_msgs/msg/Odometry`, use `go2w_tf.launch.py publish_odom_tf:=true`. Use `go2w_tf.launch.py publish_camera_tf:=true` only with measured camera values.

RViz fixed frame wrong:

Set Fixed Frame to the frame in the PointCloud2/Odometry header, commonly `odom`, `map`, or a LiDAR frame during early inspection.

RViz shows Color/Depth but no Nvblox mesh/map:

Check RViz display types before debugging the mapping pipeline. `/nvblox_node/mesh` is `nvblox_msgs/msg/Mesh`, so it must use `nvblox_rviz_plugin/NvbloxMesh`, not a MarkerArray display. `/nvblox_node/static_map_slice` is `nvblox_msgs/msg/DistanceMapSlice`, not a normal `nav_msgs/msg/OccupancyGrid`; use `/nvblox_node/static_occupancy_grid` for a standard RViz Map display. `ros2 topic list` can include topics that only exist because RViz subscribed to them, so confirm real publishers with `ros2 topic info -v <topic>`.

Check depth image, camera info, TF, and Nvblox node logs. Also inspect:

```bash
ros2 node list | grep -E 'nvblox|visual|slam'
ros2 topic list -t | grep -Ei 'nvblox|mesh|esdf|tsdf'
ros2 param get /nvblox_node global_frame
ros2 param get /nvblox_node map_clearing_frame_id
ros2 run tf2_ros tf2_echo odom base
ros2 run tf2_ros tf2_echo base camera_link
ros2 run tf2_ros tf2_echo odom camera_depth_optical_frame
ros2 run tf2_ros tf2_echo camera_link camera0_link  # only if alias enabled
ldd /opt/ros/humble/lib/libvisual_slam_node.so | grep -i 'not found\|cublas\|cusolver\|cuda'
```

In RViz, check whether the status panel reports `Global Status: Frame [odom] does not exist`. With the official NVIDIA RealSense bag, `visual_slam_node` must run because it provides the cuVSLAM odom/TF chain, commonly around `camera0_link` and `odom`. Missing `libcublas.so.12` or `libcusolver.so.11` can prevent that node from loading, so Color/Depth may appear while Nvblox has no useful global frame.

For the Go2-W feasibility harness, Visual SLAM is optional. The required chain is `odom -> base -> camera_link`, provided by Go2 odometry TF plus the measured RealSense static transform. Check it with:

```bash
ros2 run tf2_ros tf2_echo odom base
ros2 run tf2_ros tf2_echo base camera_link
```

Official NVIDIA RealSense bag:

- Uses `camera0_link`, `visual_slam_node`, and `odom` from cuVSLAM.
- Needs Visual SLAM CUDA dependencies to be complete.

Go2-W feasibility harness:

- Uses Go2 odometry TF and measured RealSense extrinsics.
- Does not require Visual SLAM when `odom -> base -> camera_link` is available.

Ghosting or double walls:

Check camera extrinsics, odometry quality, time synchronization, and whether the fixed frame is jumping. Repeat the static standing test first.

CUDA/VPI missing library issue:

```bash
ldd /opt/ros/humble/lib/libnvblox_ros_lib.so | grep -i "not found\|cuda\|cudart\|nvvpi\|npp"
ldd /opt/ros/humble/lib/libvisual_slam_node.so | grep -i "not found\|cublas\|cusolver\|cuda"
```

Rebuild the Docker image after Dockerfile dependency changes. Keep the container on Humble/Jammy; do not add Jazzy or Ubuntu 24.04 package sources.
