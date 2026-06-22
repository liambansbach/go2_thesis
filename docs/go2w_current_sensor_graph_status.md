# Go2-W Current Sensor Graph Status

Concise status after the June 22, 2026 live/home tests. This is a snapshot of
what was observed in recorded bags and module-active topic captures; it does
not change runtime behavior.

## Domain 0 Raw Status

- `/camera/...` RealSense topics are present, including depth/color images and
  camera_info.
- `/utlidar/cloud` is present and populated.
- `/lowstate` and `/sportmodestate` are present. The `/lf/lowstate` and
  `/lf/sportmodestate` variants were also visible in the raw captures.
- `/utlidar/robot_odom` and `/utlidar/robot_pose` exist in the recorded bags
  but have zero messages.

## Domain 0 RViz-Clean Replay Status

- `/tf`, `/tf_static`, `/robot_description`, `/joint_states`, `/camera/...`,
  and `/utlidar/cloud` replay correctly from the RViz-clean Domain 0 bag.
- This is the recommended offline RViz/debug bag workflow: replay the clean
  sensor, robot-description, joint-state, and TF topics instead of depending on
  live robot discovery.

## Domain 10 Modules-Active Status

When the MyBotShop modules are active, these vendor topics are available:

- `/go2_unit_38712/tf`
- `/go2_unit_38712/tf_static`
- `/go2_unit_38712/robot_description`
- `/go2_unit_38712/joint_states`
- `/go2_unit_38712/platform/joint_states`

The odometry-looking Domain 10 topics were not useful in the June 22 bags:

- `/go2_unit_38712/base/odom` has zero messages.
- `/go2_unit_38712/utlidar/robot_odom` has zero messages.

## Domain Bridge Conclusion

- The bridge is useful as a read-only path for vendor TF, RobotDescription, and
  JointStates when those are only visible in Domain 10.
- The bridge is not useful for odometry unless a real populated odom publisher
  appears.
- Do not run the full `publish_robot_description_tf:=true` helper on top of
  bridged vendor TF; that creates duplicate or competing robot-frame authority.

## RealSense Conclusion

- `camera_name:=front_realsense` was tested and produced clean
  `/front_realsense/...` topics plus `front_realsense_depth_optical_frame` and
  `front_realsense_color_optical_frame`.
- This should become the preferred future Jetson RealSense service
  configuration.
- `publish_realsense_camera_link_alias` is legacy compatibility for old
  `/camera` / `camera_name:=camera` bags and services. Keep it disabled by
  default.

## Mapping And Thesis Conclusion

- Do not make Nvblox a hard dependency while no robust dynamic
  `odom -> base_link` source exists.
- Prefer recent raw RealSense depth plus LiDAR data as robot-centric policy
  input.
- Keep Nvblox as an optional feasibility/demo path if a stable odometry source
  is later found.
