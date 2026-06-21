# Code Overview

Where to change things in the Go2-W-first repository.

## Repository Structure

```text
go2_thesis/
├── bags/                         local rosbag data, ignored/generated
├── docker/                       container image, compose file, ROS entrypoint
├── docs/                         setup, workflow, live-test, and runtime notes
├── requirements/                 Python requirement files
├── ros2_ws/
│   └── src/
│       ├── go2_bringup/          Go2-W launch, TF, RViz, Nvblox config
│       ├── go2w_description/     canonical Go2-W URDF, meshes, joint config
│       ├── risk_map_projection/  future risk projection package
│       └── semantic_risk_node/   future semantic perception package
├── scripts/                      workflow helpers
└── third_party/                  external source trees
```

Generated folders such as `ros2_ws/build/`, `ros2_ws/install/`, `ros2_ws/log/`, `bags/`, and third-party build outputs should not be edited manually.

## `docker/`

- `Dockerfile.humble`: ROS 2 Humble, Unitree dependencies, Nvblox/RealSense/domain_bridge dependencies, RViz, rosbag, and Python/system tools.
- `docker-compose.yaml`: host-networked container and workspace mount.
- `ros_entrypoint.sh`: sources ROS overlays and creates a CycloneDDS interface config dynamically when `ROS_NET_IFACE` is set.

Change these files only for container dependencies, mounted paths, environment setup, or Docker runtime behavior.

## `scripts/`

Workflow helpers are grouped by purpose:

```text
scripts/docker/   build, run, shell, stop
scripts/setup/    host/network/setup checks and workspace builds
scripts/inspect/  read-only topic, TF, RealSense, Nvblox inspection helpers
scripts/record/   Go2-W bag recorder
```

Use `scripts/README_scripts.md` for detailed commands and launch-wrapper examples. The canonical recorder is `scripts/record/record_go2w_bag.sh`.

## `ros2_ws/src/go2_bringup/`

Go2-W bringup and debug package.

Change here for:
- launch wrappers such as `go2w_nvblox.launch.py`, `go2w_debug_rviz.launch.py`, and `go2w_tf.launch.py`
- the optional read-only `go2w_domain_bridge.launch.py` Domain 10 -> Domain 0 normalization bridge
- read-only TF helpers and visualization bridges
- package-installed RViz profiles in `rviz/`
- package-owned Nvblox and domain bridge config in `config/nvblox/` and `config/domain_bridge/`

Do not change odometry logic, LowState mapping, sensor transforms, Docker behavior, or Nvblox parameters unless that is the explicit task.

Normal live Go2-W tests consume onboard-published RealSense topics over Ethernet. The canonical thesis graph is Domain 0 with `/tf`, `/tf_static`, `/joint_states`, `/robot_description`, `/camera/...` or future `/front_realsense/...`, `/utlidar/...`, `/odom`, and `/nvblox_node/...`. Domain 10 vendor/MyBotShop topics can be bridged read-only into Domain 0 when useful; command/control topics are intentionally not bridged.

## `ros2_ws/src/go2w_description/`

Canonical editable Go2-W description package.

Change here for:
- URDF files under `urdf/`
- meshes under `dae/`
- joint-name config under `config/`
- package-local description/RViz launch support

Mesh paths should resolve through `package://go2w_description/...`. The old root-level duplicate description tree has been removed.

The WR thesis URDF names the custom front RealSense mount as:

```text
base_link
└── front_realsense_base
    └── front_realsense_tilt_axis
        └── front_realsense_mount
            └── front_realsense_body
                └── front_realsense
```

`front_realsense_pitch_joint` is the mechanical pitch adjustment about the
flange axis; keep camera pitch tuning there. `front_realsense_body` holds the
currently installed D456 body visual. `front_realsense` is the canonical
RealSense depth-origin / left-imager frame, and the frame names stay generic so
a D435i or another RealSense can use the same physical mount naming after the
model-specific body-to-sensor offset and visual mesh are updated. Do not use
`camera_link` for this mount in the URDF; vendor Domain 10 TF may already
publish that child frame. RealSense optical frames should normally come from the
RealSense driver.

## `semantic_risk_node`

Future semantic perception package. Intended role:

```text
RGB image input -> semantic/risk outputs and debug overlays
```

## `risk_map_projection`

Future projection package. Intended role:

```text
risk image + depth/LiDAR + camera calibration + TF -> risk pointcloud or grid-map layer
```

## `docs/go2_runtime/`

Generated runtime inspection output:

```text
docs/go2_runtime/
```

Do not hand-edit generated scan folders. Use the inspection scripts to create new evidence when the robot, bags, or ROS graph change. Keep active ROS configuration in the owning package, usually `ros2_ws/src/go2_bringup/config/`.

## `bags/`

Local rosbag data. This directory is ignored because recordings are large.

## `third_party/`

External repositories. Do not edit generated build/install/log folders under third-party workspaces.

## `requirements/`

Python requirement files for development or future perception/projection tooling.
