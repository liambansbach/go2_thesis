from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition, UnlessCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import ComposableNodeContainer, Node
from launch_ros.descriptions import ComposableNode
from launch_ros.parameter_descriptions import ParameterValue
from launch_ros.substitutions import FindPackageShare

# Live: ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=false launch_realsense:=false
# Replay: ros2 bag play bags/<bag_name> --clock; ros2 launch go2_bringup go2w_nvblox.launch.py use_sim_time:=true launch_realsense:=false
# Static feasibility harness only: no navigation, no autonomous robot commands.


def generate_launch_description():
    nvblox_config = PathJoinSubstitution([
        FindPackageShare('go2_bringup'),
        'config',
        'nvblox',
        'go2w_static_realsense.yaml',
    ])
    nvblox_base_config = PathJoinSubstitution([
        FindPackageShare('nvblox_examples_bringup'),
        'config',
        'nvblox',
        'nvblox_base.yaml',
    ])

    args = [
        DeclareLaunchArgument('use_rviz', default_value='true'),
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument('log_level', default_value='info'),
        DeclareLaunchArgument(
            'launch_realsense',
            default_value='false',
            description=(
                'Use the full Isaac ROS RealSense example. Leave false for '
                'Go2-W bag/live replay where /camera topics already exist.'
            ),
        ),
        DeclareLaunchArgument('nvblox_config', default_value=nvblox_config),
        DeclareLaunchArgument('global_frame', default_value='odom'),
        DeclareLaunchArgument('map_clearing_frame_id', default_value='base'),
        DeclareLaunchArgument('voxel_size', default_value='0.08'),
        DeclareLaunchArgument('use_color', default_value='true'),
        DeclareLaunchArgument('enable_lidar', default_value='false'),
        DeclareLaunchArgument(
            'container_name',
            default_value='nvblox_container',
            description='Composable node container used by Nvblox.',
        ),
        DeclareLaunchArgument(
            'publish_camera0_alias_tf',
            default_value='false',
            description=(
                'Publish an identity camera_link -> camera0_link static TF '
                'only for compatibility with Isaac ROS examples/configs that '
                'expect camera0_link. This is not a physical calibration.'
            ),
        ),
        DeclareLaunchArgument(
            'camera0_alias_parent_frame',
            default_value='camera_link',
            description='Parent frame for the optional camera0_link alias.',
        ),
        DeclareLaunchArgument(
            'camera0_alias_child_frame',
            default_value='camera0_link',
            description='Child frame for the optional camera0_link alias.',
        ),
        DeclareLaunchArgument(
            'depth_image_topic',
            default_value='/camera/depth/image_rect_raw',
            description='RealSense depth topic remapped to camera_0/depth/image. '
                        'Fallbacks include /camera/camera/depth/image_rect_raw '
                        'and /camera/aligned_depth_to_color/image_raw.',
        ),
        DeclareLaunchArgument(
            'depth_camera_info_topic',
            default_value='/camera/depth/camera_info',
            description='RealSense depth CameraInfo remapped to camera_0/depth/camera_info. '
                        'Fallbacks include /camera/camera/depth/camera_info '
                        'and /camera/aligned_depth_to_color/camera_info.',
        ),
        DeclareLaunchArgument(
            'color_image_topic',
            default_value='/camera/color/image_raw',
            description='RealSense color topic remapped to camera_0/color/image. '
                        'Fallback: /camera/camera/color/image_raw.',
        ),
        DeclareLaunchArgument(
            'color_camera_info_topic',
            default_value='/camera/color/camera_info',
            description='RealSense color CameraInfo remapped to camera_0/color/camera_info. '
                        'Fallback: /camera/camera/color/camera_info.',
        ),
        DeclareLaunchArgument(
            'lidar_topic',
            default_value='/utlidar/cloud',
            description='Optional Unitree LiDAR PointCloud2 topic used only when enable_lidar:=true.',
        ),
    ]

    # Normal Go2-W replay/live operation consumes existing /camera/... topics.
    # Do not include the full RealSense example here: it starts extra perception
    # pieces and can hard-code /camera0 plus camera0_link assumptions.
    nvblox_node = ComposableNode(
        name='nvblox_node',
        package='nvblox_ros',
        plugin='nvblox::NvbloxNode',
        remappings=[
            ('camera_0/depth/image', LaunchConfiguration('depth_image_topic')),
            (
                'camera_0/depth/camera_info',
                LaunchConfiguration('depth_camera_info_topic'),
            ),
            ('camera_0/color/image', LaunchConfiguration('color_image_topic')),
            (
                'camera_0/color/camera_info',
                LaunchConfiguration('color_camera_info_topic'),
            ),
            ('pointcloud', LaunchConfiguration('lidar_topic')),
        ],
        parameters=[
            nvblox_base_config,
            LaunchConfiguration('nvblox_config'),
            {
                'use_sim_time': ParameterValue(
                    LaunchConfiguration('use_sim_time'),
                    value_type=bool,
                ),
                'mapping_type': 'static_tsdf',
                'use_depth': True,
                'use_color': ParameterValue(
                    LaunchConfiguration('use_color'),
                    value_type=bool,
                ),
                'use_lidar': ParameterValue(
                    LaunchConfiguration('enable_lidar'),
                    value_type=bool,
                ),
                'use_segmentation': False,
                'use_tf_transforms': True,
                'use_topic_transforms': False,
                'global_frame': LaunchConfiguration('global_frame'),
                'map_clearing_frame_id': LaunchConfiguration(
                    'map_clearing_frame_id'
                ),
                'map_clearing_radius_m': 5.0,
                'voxel_size': ParameterValue(
                    LaunchConfiguration('voxel_size'),
                    value_type=float,
                ),
                'input_qos': 'SENSOR_DATA',
                'print_rates_to_console': True,
                'print_timings_to_console': True,
                'print_delays_to_console': True,
                'print_statistics_on_console_period_ms': 10000,
            },
        ],
    )

    nvblox_container = ComposableNodeContainer(
        condition=UnlessCondition(LaunchConfiguration('launch_realsense')),
        name=LaunchConfiguration('container_name'),
        namespace='',
        package='rclcpp_components',
        executable='component_container_mt',
        composable_node_descriptions=[nvblox_node],
        arguments=[
            '--ros-args',
            '--log-level',
            LaunchConfiguration('log_level'),
        ],
        output='screen',
    )

    # Optional fallback for testing a locally connected RealSense with NVIDIA's
    # full example. This is intentionally not used for normal Go2-W bags/live
    # tests, because those already provide camera topics from the robot/bag.
    realsense_example_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution([
                FindPackageShare('nvblox_examples_bringup'),
                'launch',
                'realsense_example.launch.py',
            ])
        ),
        condition=IfCondition(LaunchConfiguration('launch_realsense')),
        launch_arguments={
            'use_sim_time': LaunchConfiguration('use_sim_time'),
            'run_realsense': 'True',
            'run_rviz': 'false',
            'use_rviz': 'false',
        }.items(),
    )

    # Compatibility alias only. Prefer fixing Nvblox parameters/remaps to use
    # the real Go2-W TF tree; this transform is not a sensor calibration.
    camera0_alias_tf = Node(
        condition=IfCondition(LaunchConfiguration('publish_camera0_alias_tf')),
        package='tf2_ros',
        executable='static_transform_publisher',
        name='go2w_camera0_link_alias_tf',
        arguments=[
            '--x',
            '0.0',
            '--y',
            '0.0',
            '--z',
            '0.0',
            '--roll',
            '0.0',
            '--pitch',
            '0.0',
            '--yaw',
            '0.0',
            '--frame-id',
            LaunchConfiguration('camera0_alias_parent_frame'),
            '--child-frame-id',
            LaunchConfiguration('camera0_alias_child_frame'),
        ],
        output='screen',
    )

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

    return LaunchDescription(args + [
        nvblox_container,
        realsense_example_launch,
        camera0_alias_tf,
        rviz,
    ])
