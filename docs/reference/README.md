# Reference Files

This folder contains reference-only snapshots and checklists. Files here are not
loaded by launch files or runtime code unless a future change explicitly wires
them into a ROS package.

- `topics/`: topic snapshots and candidate topic-name checklists.
- `frames/`: candidate frame names and TF inspection notes.
- `calibration/`: Go2-W sensor-extrinsic notes. Values marked rough or TODO are
  not measured calibration.

Keep active ROS package configuration in the owning package, for example
`ros2_ws/src/go2_bringup/config/`. CycloneDDS interface config is generated
dynamically by `docker/ros_entrypoint.sh` when `ROS_NET_IFACE` is set.
