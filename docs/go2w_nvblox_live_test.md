# Go2-W Nvblox Live Test

Canonical procedure for the next Go2-W thesis live test. This repository must stay read-only with respect to robot motion: no `/cmd_vel`, no sport requests, no e-stop publishing, and no autonomous navigation launch.

## Architecture

```text
Canonical thesis graph:
  ROS_DOMAIN_ID=0
  /tf
  /tf_static
  /joint_states
  /robot_description
  /camera/... or future /front_realsense/...
  /utlidar/...
  /odom
  /nvblox_node/...

Optional vendor/MyBotShop source graph:
  ROS_DOMAIN_ID=10
  /go2_unit_38712/tf
  /go2_unit_38712/tf_static
  /go2_unit_38712/joint_states
  /go2_unit_38712/platform/joint_states
  /go2_unit_38712/robot_description
  ...
```

The custom front RealSense mount is:

```text
base_link
└── front_realsense_base
    └── front_realsense_tilt_axis
        └── front_realsense_mount
            └── front_realsense_body
                └── front_realsense
```

The frame names are model-flexible. The currently installed camera is a D456, but a D435i or another RealSense can use the same mount naming. `front_realsense_pitch_joint` in the URDF, or `front_realsense_pitch` in the TF complement launch, is the one place to tune the camera pitch about the flange axis. `front_realsense_body` is the D456 body/rear-face visual helper. `front_realsense` is the canonical RealSense depth-origin / left-imager frame; update the D456-specific body-to-sensor offset and visual mesh before installing a D435i or another model. Do not treat vendor `camera_link` as the thesis front RealSense mount. RealSense optical frames should normally come from the RealSense driver; the live audit checks whether those optical frames are connected to `front_realsense`.

The current Jetson `go2-realsense-domain0.service` remains the live camera source. Local USB RealSense testing is outside the normal live workflow. The preferred final Jetson RealSense configuration is model-flexible front-mount frame naming, if the driver supports it cleanly: `front_realsense`, `front_realsense_depth_frame`, `front_realsense_depth_optical_frame`, `front_realsense_color_frame`, and `front_realsense_color_optical_frame`. Until that is verified on the robot, inspect the actual camera header frame IDs and TF chain during every live test. If the driver still publishes `camera_depth_optical_frame` below `camera_link`, inspect the real tree before adding any alias. Do not add a fake `front_realsense -> camera_link` alias unless live inspection proves it is explicitly required. Do not bridge or publish command/control topics.

## Start

On the host:

```bash
ip -br addr
./scripts/setup/setup_go2_ethernet.sh <iface>
ROS_NET_IFACE=<iface> ./scripts/docker/run.sh
```

Inside the container:

```bash
echo "$ROS_DISTRO"
echo "$RMW_IMPLEMENTATION"
echo "$ROS_DOMAIN_ID"
./scripts/inspect/inspect_ros_domains.sh
```

If Domain 10 has useful vendor TF/state, bridge only the safe read-only topics into Domain 0:

```bash
ros2 launch go2_bringup go2w_domain_bridge.launch.py
```

The bridge config intentionally excludes command, request, teleop, e-stop, and robot-state-changing topics.

## RealSense And TF Audit

Run the RealSense/front-mount audit:

```bash
./scripts/inspect/inspect_realsense_topics.sh
```

This captures camera topic headers, a filtered TF tree, and these checks:

```bash
ros2 run tf2_ros tf2_echo base_link front_realsense_base
ros2 run tf2_ros tf2_echo front_realsense_base front_realsense_tilt_axis
ros2 run tf2_ros tf2_echo front_realsense_tilt_axis front_realsense_mount
ros2 run tf2_ros tf2_echo front_realsense_mount front_realsense_body
ros2 run tf2_ros tf2_echo front_realsense_body front_realsense
ros2 run tf2_ros tf2_echo base_link front_realsense
ros2 run tf2_ros tf2_echo front_realsense camera_depth_optical_frame
ros2 run tf2_ros tf2_echo front_realsense front_realsense_depth_optical_frame
ros2 run tf2_ros tf2_echo odom camera_depth_optical_frame
```

Before changing any Jetson service, audit which RealSense wrapper frame
parameters the live node supports:

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

If `ros2 node list` shows a different camera node, repeat the same commands
with `RS_NODE=/camera`, `RS_NODE=/front_realsense/camera`,
`RS_NODE=/front/camera`, or the actual listed node name.

Best final setup: configure the Jetson RealSense driver, if it supports a clean
parameter combination, so its internal sensor/optical TF tree is published below
the thesis frame:

```text
base_link -> ... -> front_realsense -> front_realsense_depth_frame -> front_realsense_depth_optical_frame
```

If the wrapper only produces `camera_link` / `camera_depth_optical_frame`,
inspect the live TF tree before adding any compatibility alias. Do not add a
fake `front_realsense -> camera_link` alias automatically.

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

The topic namespace may change when `camera_namespace` or `camera_name` changes,
so `go2w_nvblox.launch.py` topic arguments may need explicit overrides.

If the custom front mount is missing from TF, publish only that complement:

```bash
ros2 launch go2_bringup go2w_tf.launch.py publish_front_realsense_tf:=true
```

For static standing sanity checks only:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_static_odom_tf:=true \
  base_frame:=base_link
```

Moving tests require a real dynamic `odom -> base_link`. Enable the odometry-to-TF bridge only after `ros2 topic info -v <odom_topic>` and a message sample prove that the selected topic is a populated `nav_msgs/Odometry` stream:

```bash
ros2 launch go2_bringup go2w_tf.launch.py \
  publish_odom_tf:=true \
  odom_topic:=/utlidar/robot_odom
```

Use `publish_robot_description_tf:=true` only when vendor `/tf` and `/tf_static` are not available. Do not run the full URDF publisher on top of bridged vendor TF unless intentionally debugging duplicate child frames.

## Nvblox

Start with RealSense-only Nvblox:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=false \
  launch_realsense:=false \
  global_frame:=odom \
  map_clearing_frame_id:=base_link \
  voxel_size:=0.08 \
  enable_lidar:=false
```

Nvblox requires a valid transform from `global_frame` to the camera optical frame. For static sanity tests, a fake `odom -> base_link` is acceptable. For moving tests, use a real dynamic `odom -> base_link`.

If the camera topics are renamed later, override only the visible topic arguments:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  depth_image_topic:=/front_realsense/depth/image_rect_raw \
  depth_camera_info_topic:=/front_realsense/depth/camera_info \
  color_image_topic:=/front_realsense/color/image_raw \
  color_camera_info_topic:=/front_realsense/color/camera_info
```

Optional Nvblox/system capture after the node is running:

```bash
./scripts/inspect/inspect_go2w_nvblox_topics.sh
```

## Replay

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
`base_link`/`front_realsense` URDF tree; RViz will show parallel old and new TF
worlds. To test only the new static robot/RealSense tree, launch
`go2w_tf.launch.py` without bag replay. To use old sensor data with the current
tree, replay only selected sensor topics and avoid old TF/robot-description
topics. Old bags are still useful for qualitative sensor visualization, but
they are not a clean validation of the current `front_realsense` TF
architecture. Do not add a permanent `front_realsense -> camera_link` alias just
to make old bags look clean.

Then use the same TF and Nvblox commands with `use_sim_time:=true`. Prefer one bag pass for TF validation; looping can produce `TF_OLD_DATA` warnings when simulated time jumps backward.

## Record

Use one canonical recorder:

```bash
./scripts/record/record_go2w_bag.sh mapping_raw <label>
./scripts/record/record_go2w_bag.sh nvblox_debug <label>
```

Do not modify existing bag data during inspection or cleanup.
