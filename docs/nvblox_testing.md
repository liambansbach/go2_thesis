# Nvblox Testing

Short notes for Nvblox setup and local quickstarts. Use `docs/go2w_nvblox_live_test.md` as the source of truth for the detailed Go2-W live RealSense/Nvblox workflow.

The project targets Ubuntu 22.04 + ROS 2 Humble inside Docker. Nvblox is installed through the Isaac ROS release-3 Jammy packages, and RealSense support uses Humble Debian packages.

## Setup Check

Inside the container:

```bash
./scripts/setup/check_nvblox_setup.sh
```

This checks ROS, CycloneDDS, NVIDIA runtime visibility, installed Nvblox/Isaac/RealSense packages, and the available Nvblox RealSense example arguments when present.

## Official Quickstart Assets

The official Nvblox quickstart assets are not committed with this repository.

Download them when needed:

```bash
./scripts/setup/download_nvblox_assets.sh
```

Run the official quickstart manually:

```bash
ros2 launch nvblox_examples_bringup isaac_sim_example.launch.py \
  rosbag:=/workspaces/go2_thesis/bags/isaac_ros_assets/isaac_ros_nvblox/quickstart \
  navigation:=False
```

This checks Nvblox, GPU, and RViz at a basic level. It does not validate Go2-W RealSense mounting, Go2-W TF, or robot odometry.

## Local Go2-W Wrapper Smoke Test

After building and sourcing `ros2_ws`, the repository wrapper for RealSense-only Nvblox is:

```bash
ros2 launch go2_bringup go2w_nvblox.launch.py \
  use_rviz:=true \
  use_sim_time:=false \
  launch_realsense:=true
```

For the full live-test sequence, including preflight, Ethernet setup, RealSense checks, TF checks, bag recording, replay, and troubleshooting, use:

```text
docs/go2w_nvblox_live_test.md
```

## Known Setup Issues

- If `ros-humble-isaac-ros-nvblox` is not found during Docker build, keep the container on Ubuntu 22.04 and ROS 2 Humble. Check the Isaac ROS release-3 Jammy apt repository rather than adding Jazzy or Ubuntu 24.04 package sources.
- If RViz opens but no mesh or ESDF appears, `nvblox_node` may have failed to load CUDA/VPI runtime libraries. Diagnose inside the container with:

  ```bash
  ldd /opt/ros/humble/lib/libnvblox_ros_lib.so | grep -i "not found\|cuda\|cudart\|nvvpi\|npp"
  ```

- Rebuild the Docker image after dependency changes.
