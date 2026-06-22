# Scripts

Script reference only. Use `docs/workflow.md` for the daily command sequence.
Old root-level script paths were intentionally removed to keep this folder
unambiguous.

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
- `inspect/inspect_realsense_topics.sh`: Inspect RealSense topics, headers, front-mount TF, and optical-frame connectivity. Defaults to `CAMERA_NS=/camera`; set `CAMERA_NS=/front_realsense` for the clean front-mount service.
- `inspect/inspect_go2w_nvblox_topics.sh`: Optional Nvblox/system state capture after Nvblox is running.
- `inspect/inspect_bag_topic_counts.sh`: Print sqlite3 rosbag topic names, types, and message counts, including zero-count topics.
- `inspect/robot_net_check.sh`: Check Go2 network and ROS 2 visibility.

```bash
./scripts/inspect/robot_net_check.sh
./scripts/inspect/inspect_ros_domains.sh
./scripts/inspect/inspect_realsense_topics.sh
CAMERA_NS=/front_realsense ./scripts/inspect/inspect_realsense_topics.sh
./scripts/inspect/inspect_go2w_nvblox_topics.sh
./scripts/inspect/inspect_bag_topic_counts.sh bags/<bag_dir>
```

## Record

- `record/record_go2w_bag.sh`: Canonical Go2-W bag recorder. It records a safe
  set of visible local-type-supported topics and defaults to `sqlite3` storage.
  Legacy profile names such as `mapping_raw`, `nvblox_debug`, `lidar`,
  `camera`, `state`, and `full` are accepted for compatibility and bag naming.

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

See `docs/workflow.md` for when to use these launch files and which arguments
are safe for live visualization, replay, and optional Nvblox demos.
