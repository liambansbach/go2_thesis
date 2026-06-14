from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, SetParameter, SetParametersFromFile, SetRemap
from launch_ros.substitutions import FindPackageShare

# Live: ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=false launch_realsense:=true
# Replay: ros2 bag play bags/<bag_name> --clock; ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=true launch_realsense:=false
# Static feasibility harness only: no navigation, no autonomous robot commands.


def generate_launch_description():
    nvblox_config = PathJoinSubstitution([
        FindPackageShare('go2_bringup'),
        'config',
        'nvblox',
        'go2w_static_realsense.yaml',
    ])

    args = [
        DeclareLaunchArgument('use_rviz', default_value='true'),
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument('log_level', default_value='info'),
        DeclareLaunchArgument('launch_realsense', default_value='true'),
        DeclareLaunchArgument('nvblox_config', default_value=nvblox_config),
        DeclareLaunchArgument('global_frame', default_value='odom'),
        DeclareLaunchArgument('map_clearing_frame_id', default_value='base_link'),
        DeclareLaunchArgument('voxel_size', default_value='0.08'),
        DeclareLaunchArgument('use_color', default_value='true'),
        DeclareLaunchArgument('enable_lidar', default_value='false'),
        DeclareLaunchArgument(
            'depth_image_topic',
            default_value='/camera/camera/aligned_depth_to_color/image_raw',
            description='RealSense depth topic remapped to camera_0/depth/image. '
                        'Common fallback: /camera/camera/depth/image_rect_raw.',
        ),
        DeclareLaunchArgument(
            'depth_camera_info_topic',
            default_value='/camera/camera/aligned_depth_to_color/camera_info',
            description='RealSense depth CameraInfo remapped to camera_0/depth/camera_info. '
                        'Common fallback: /camera/camera/depth/camera_info.',
        ),
        DeclareLaunchArgument(
            'color_image_topic',
            default_value='/camera/camera/color/image_raw',
            description='RealSense color topic remapped to camera_0/color/image.',
        ),
        DeclareLaunchArgument(
            'color_camera_info_topic',
            default_value='/camera/camera/color/camera_info',
            description='RealSense color CameraInfo remapped to camera_0/color/camera_info.',
        ),
        DeclareLaunchArgument(
            'lidar_topic',
            default_value='/utlidar/cloud',
            description='Optional Unitree LiDAR PointCloud2 topic used only when enable_lidar:=true.',
        ),
    ]

    nvblox_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution([
                FindPackageShare('nvblox_examples_bringup'),
                'launch',
                'realsense_example.launch.py',
            ])
        ),
        launch_arguments={
            'use_sim_time': LaunchConfiguration('use_sim_time'),
            'launch_realsense': LaunchConfiguration('launch_realsense'),
            'run_rviz': 'false',
            'use_rviz': 'false',
        }.items(),
    )

    nvblox_group = GroupAction([
        SetParametersFromFile(LaunchConfiguration('nvblox_config')),
        SetParameter(name='use_sim_time', value=LaunchConfiguration('use_sim_time')),
        SetParameter(name='mapping_type', value='static_tsdf'),
        SetParameter(name='use_depth', value=True),
        SetParameter(name='use_color', value=LaunchConfiguration('use_color')),
        SetParameter(name='use_lidar', value=LaunchConfiguration('enable_lidar')),
        SetParameter(name='use_segmentation', value=False),
        SetParameter(name='use_tf_transforms', value=True),
        SetParameter(name='use_topic_transforms', value=False),
        SetParameter(name='global_frame', value=LaunchConfiguration('global_frame')),
        SetParameter(
            name='map_clearing_frame_id',
            value=LaunchConfiguration('map_clearing_frame_id'),
        ),
        SetParameter(name='map_clearing_radius_m', value=5.0),
        SetParameter(name='voxel_size', value=LaunchConfiguration('voxel_size')),
        SetParameter(name='print_rates_to_console', value=True),
        SetParameter(name='print_timings_to_console', value=True),
        SetParameter(name='print_delays_to_console', value=True),
        SetParameter(name='print_statistics_on_console_period_ms', value=10000),

        # Visible RealSense remaps for Isaac ROS Nvblox camera_0 inputs.
        # D456 wrapper versions commonly publish either aligned_depth_to_color
        # or depth/image_rect_raw; override the launch arguments when needed.
        SetRemap(src='camera_0/depth/image', dst=LaunchConfiguration('depth_image_topic')),
        SetRemap(
            src='camera_0/depth/camera_info',
            dst=LaunchConfiguration('depth_camera_info_topic'),
        ),
        SetRemap(src='camera_0/color/image', dst=LaunchConfiguration('color_image_topic')),
        SetRemap(
            src='camera_0/color/camera_info',
            dst=LaunchConfiguration('color_camera_info_topic'),
        ),

        # TODO: Verify Unitree 4D LiDAR-specific Nvblox LiDAR parameters before
        # enabling this in evaluation runs. Do not blindly reuse VLP16/Hesai
        # defaults; keep RealSense-only as the default harness.
        SetRemap(
            condition=IfCondition(LaunchConfiguration('enable_lidar')),
            src='pointcloud',
            dst=LaunchConfiguration('lidar_topic'),
        ),
        nvblox_launch,
    ])

    rviz = Node(
        condition=IfCondition(LaunchConfiguration('use_rviz')),
        package='rviz2',
        executable='rviz2',
        name='go2w_nvblox_debug_rviz',
        arguments=[
            '-d',
            PathJoinSubstitution([
                FindPackageShare('go2_bringup'),
                'rviz',
                'go2w_nvblox_debug.rviz',
            ]),
            '--ros-args',
            '--log-level',
            LaunchConfiguration('log_level'),
        ],
        parameters=[{'use_sim_time': LaunchConfiguration('use_sim_time')}],
        output='screen',
    )

    return LaunchDescription(args + [nvblox_group, rviz])
