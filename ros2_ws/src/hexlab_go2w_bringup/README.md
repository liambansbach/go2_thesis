# HEXLab Go2-W Bringup

`hexlab_go2w_bringup` is for live Jetson/domain-10 state visualization of the HEXLab Go2-W. It is a read-only bringup package and publishes no robot command or control topics.

The `go2w_state_domain10.launch.py` launch file renders the current `hexlab_go2w_description` robot model and starts `robot_state_publisher` globally. It publishes the global robot description and TF tree, including `/robot_description`, `/tf`, and `/tf_static`.

The optional `joint_state_relay` node can relay the vendor joint state stream from `/go2_unit_46273/platform/joint_states` to the global `/joint_states` topic expected by `robot_state_publisher`. It republishes incoming `sensor_msgs/msg/JointState` messages unchanged unless its `restamp` parameter is explicitly set to `true`.

If the vendor joint state topic is missing, fixed frames still publish, but moving leg and wheel links may not update.

This package does not start RViz, Nvblox, RealSense, `joint_state_publisher`, `joint_state_publisher_gui`, or any controller. The target ROS domain is controlled by the surrounding environment or systemd service.
