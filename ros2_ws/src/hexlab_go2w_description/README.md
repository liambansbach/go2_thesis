# HEXLab Go2-W Description

`vendor/mybotshop/go2_description` is the unmodified MYBOTSHOP base description. It provides the upstream Go2 meshes and xacros used by this package.

`hexlab_go2w_description` is the HEXLab extension and the current source of truth for ROS, RViz, and Jetson visualization. It layers the lab-specific Go2-W description, front RealSense D456 mount, and local visualization launch files on top of the vendor base.

## Local Viewers

`view_hexlab_go2w.launch.py` is for local/offline model viewing only. It renders the HEXLab Go2-W xacro with the wheeled, no-arm model flags and starts `joint_state_publisher_gui` so the joints can be moved with sliders in RViz.

`view_hexlab_go2w_static.launch.py` is also local/offline only, but uses `joint_state_publisher` instead of the GUI publisher for environments where sliders are not wanted.

Live Jetson bringup must not use GUI joint publishers. Live robot visualization should use robot-provided or bridge-provided state, not local fake joint-state GUI nodes.

IsaacLab should later use a derived `hexlab_go2w_sim` package or a dedicated IsaacLab asset. It should not use the old `go2w_description` package as the source of truth.

The old `go2w_description` package is legacy/reference only.
