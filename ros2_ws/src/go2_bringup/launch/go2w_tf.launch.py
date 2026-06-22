from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

# Full URDF TF fallback:
# ros2 launch go2_bringup go2w_tf.launch.py publish_robot_description_tf:=true
#
# Use publish_robot_description_tf:=true only when vendor /tf and /tf_static are
# not available. Do not run the full URDF robot_state_publisher on top of
# bridged vendor TF unless intentionally debugging duplicate TF child frames.
#
# Offline fake static odom TF:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_robot_description_tf:=true publish_static_odom_tf:=true
#
# Thesis front RealSense TF complement, for the custom physical mount only:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_front_realsense_tf:=true
#
# Legacy RealSense camera_link compatibility, disabled by default:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_realsense_camera_link_alias:=true
#
# Dynamic odometry bridge, disabled by default:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_odom_tf:=true odom_topic:=/utlidar/robot_odom
#
# Experimental LiDAR visual alignment, disabled by default:
# ros2 launch go2_bringup go2w_tf.launch.py publish_lidar_tf:=true


def _robot_state_publisher(context, *args, **kwargs):
    robot_description_file = LaunchConfiguration(
        'robot_description_file'
    ).perform(context)
    with open(robot_description_file, 'r', encoding='utf-8') as urdf_file:
        robot_description = urdf_file.read()

    return [
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            name='go2w_robot_state_publisher',
            parameters=[{
                'robot_description': robot_description,
                'use_sim_time': LaunchConfiguration('use_sim_time'),
            }],
            output='screen',
        )
    ]


def _static_tf_node(name, condition, parent_frame, child_frame,
                    x, y, z, roll, pitch, yaw):
    return Node(
        condition=condition,
        package='tf2_ros',
        executable='static_transform_publisher',
        name=name,
        arguments=[
            '--x', x,
            '--y', y,
            '--z', z,
            '--roll', roll,
            '--pitch', pitch,
            '--yaw', yaw,
            '--frame-id', parent_frame,
            '--child-frame-id', child_frame,
        ],
        output='screen',
    )


def generate_launch_description():
    args = [
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument(
            'publish_robot_description_tf',
            default_value='false',
            description=(
                'Publish fixed/movable TF from the installed Go2-W URDF. '
                'Use only when vendor /tf and /tf_static are unavailable; '
                'otherwise it can duplicate bridged vendor child frames.'
            ),
        ),
        DeclareLaunchArgument(
            'robot_description_file',
            default_value=PathJoinSubstitution([
                FindPackageShare('go2w_description'),
                'urdf',
                'go2w_description_wr.urdf',
            ]),
            description='URDF file used by robot_state_publisher.',
        ),
        DeclareLaunchArgument(
            'joint_names_file',
            default_value=PathJoinSubstitution([
                FindPackageShare('go2w_description'),
                'config',
                'joint_names_go2w_description.yaml',
            ]),
            description=(
                'Optional parameter file for LowState joint-name ordering.'
            ),
        ),
        DeclareLaunchArgument(
            'publish_static_odom_tf',
            default_value='false',
            description=(
                'Publish a fake static identity odom->base_frame transform for '
                'offline standing/RViz/Nvblox sanity checks only. Never use '
                'for moving-map evaluation.'
            ),
        ),
        DeclareLaunchArgument('odom_frame', default_value='odom'),
        DeclareLaunchArgument('base_frame', default_value='base_link'),
        DeclareLaunchArgument(
            'publish_lowstate_joint_states',
            default_value='false',
            description=(
                'Publish /joint_states from Unitree LowState for '
                'visualization only when /joint_states is not already '
                'provided by the vendor/domain bridge. Requires the Unitree '
                'message overlay.'
            ),
        ),
        DeclareLaunchArgument('lowstate_topic', default_value='/lowstate'),
        DeclareLaunchArgument(
            'publish_front_realsense_tf',
            default_value='false',
            description=(
                'Publish the thesis front RealSense complement chain: '
                'base_link to front_realsense_base to '
                'front_realsense_tilt_axis to front_realsense_mount to '
                'front_realsense_body to front_realsense. Does not publish '
                'flange visual frames, camera_link, or optical frames.'
            ),
        ),
        DeclareLaunchArgument(
            'front_realsense_parent_frame',
            default_value='base_link',
        ),
        DeclareLaunchArgument(
            'front_realsense_base_frame',
            default_value='front_realsense_base',
        ),
        DeclareLaunchArgument(
            'front_realsense_tilt_axis_frame',
            default_value='front_realsense_tilt_axis',
        ),
        DeclareLaunchArgument(
            'front_realsense_mount_frame',
            default_value='front_realsense_mount',
        ),
        DeclareLaunchArgument(
            'front_realsense_body_frame',
            default_value='front_realsense_body',
        ),
        DeclareLaunchArgument(
            'front_realsense_frame',
            default_value='front_realsense',
        ),
        DeclareLaunchArgument(
            'publish_realsense_camera_link_alias',
            default_value='false',
            description=(
                'Publish an identity front_realsense->camera_link static TF '
                'for legacy RealSense wrappers/services that publish '
                'camera_link-based optical frames. Keep disabled unless the '
                'live RealSense tree requires this compatibility bridge.'
            ),
        ),
        DeclareLaunchArgument('front_realsense_base_x', default_value='0.295'),
        DeclareLaunchArgument('front_realsense_base_y', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_base_z', default_value='0.075'),
        DeclareLaunchArgument('front_realsense_base_roll', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_base_pitch', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_base_yaw', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_tilt_axis_x', default_value='0.005'),
        DeclareLaunchArgument('front_realsense_tilt_axis_y', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_tilt_axis_z', default_value='0.032'),
        DeclareLaunchArgument('front_realsense_mount_x', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_mount_y', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_mount_z', default_value='0.0'),
        DeclareLaunchArgument(
            'front_realsense_pitch',
            default_value='0.0',
            description=(
                'Camera pitch about the front_realsense_tilt_axis local Y '
                'axis. Match front_realsense_pitch_joint in the URDF.'
            ),
        ),
        DeclareLaunchArgument('front_realsense_mount_roll', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_mount_yaw', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_body_x', default_value='0.02'),
        DeclareLaunchArgument('front_realsense_body_y', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_body_z', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_body_roll', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_body_pitch', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_body_yaw', default_value='0.0'),
        DeclareLaunchArgument('front_realsense_sensor_x', default_value='0.02145'),
        DeclareLaunchArgument('front_realsense_sensor_y', default_value='0.04750'),
        DeclareLaunchArgument('front_realsense_sensor_z', default_value='0.0'),
        DeclareLaunchArgument(
            'publish_lidar_tf',
            default_value='false',
            description=(
                'Publish experimental radar->utlidar_lidar static TF for '
                'offline visual alignment only.'
            ),
        ),
        DeclareLaunchArgument('lidar_parent_frame', default_value='radar'),
        DeclareLaunchArgument(
            'lidar_child_frame',
            default_value='utlidar_lidar',
        ),
        DeclareLaunchArgument('lidar_x', default_value='0.0'),
        DeclareLaunchArgument('lidar_y', default_value='0.0'),
        DeclareLaunchArgument('lidar_z', default_value='0.0'),
        DeclareLaunchArgument('lidar_roll', default_value='0.0'),
        DeclareLaunchArgument('lidar_pitch', default_value='0.0'),
        DeclareLaunchArgument('lidar_yaw', default_value='-2.09439510239'), # -120 degrees to roughly align the front of the LiDAR FOV with the front of the robot, based on visual inspection of the cloud in RViz. This is not a verified physical calibration.
        DeclareLaunchArgument(
            'publish_odom_tf',
            default_value='false',
            description=(
                'Publish TF from a selected nav_msgs/Odometry topic only when '
                'that topic has actual messages.'
            ),
        ),
        DeclareLaunchArgument(
            'odom_topic',
            default_value='/utlidar/robot_odom',
        ),
        DeclareLaunchArgument('odom_parent_frame', default_value=''),
        DeclareLaunchArgument('odom_child_frame', default_value=''),
    ]

    robot_description_tf = OpaqueFunction(
        condition=IfCondition(
            LaunchConfiguration('publish_robot_description_tf')
        ),
        function=_robot_state_publisher,
    )

    # Fake/static identity TF for static standing/RViz/Nvblox sanity checks
    # only. Do not use this for moving-map evaluation; Nvblox needs real
    # dynamic odom -> base_link when the robot moves.
    static_odom_tf = Node(
        condition=IfCondition(LaunchConfiguration('publish_static_odom_tf')),
        package='tf2_ros',
        executable='static_transform_publisher',
        name='go2w_fake_static_odom_tf',
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
            LaunchConfiguration('odom_frame'),
            '--child-frame-id',
            LaunchConfiguration('base_frame'),
        ],
        output='screen',
    )

    # Clean complement for vendor TF: publish only the non-visual front
    # RealSense chain that the Domain 10 vendor tree should not already own.
    # Flange visual frames come from URDF/RobotModel only. This intentionally
    # avoids camera_link and optical frames.
    front_realsense_condition = IfCondition(
        LaunchConfiguration('publish_front_realsense_tf')
    )
    front_realsense_base_tf = _static_tf_node(
        'go2w_front_realsense_base_static_tf',
        front_realsense_condition,
        LaunchConfiguration('front_realsense_parent_frame'),
        LaunchConfiguration('front_realsense_base_frame'),
        LaunchConfiguration('front_realsense_base_x'),
        LaunchConfiguration('front_realsense_base_y'),
        LaunchConfiguration('front_realsense_base_z'),
        LaunchConfiguration('front_realsense_base_roll'),
        LaunchConfiguration('front_realsense_base_pitch'),
        LaunchConfiguration('front_realsense_base_yaw'),
    )
    front_realsense_tilt_axis_tf = _static_tf_node(
        'go2w_front_realsense_tilt_axis_static_tf',
        front_realsense_condition,
        LaunchConfiguration('front_realsense_base_frame'),
        LaunchConfiguration('front_realsense_tilt_axis_frame'),
        LaunchConfiguration('front_realsense_tilt_axis_x'),
        LaunchConfiguration('front_realsense_tilt_axis_y'),
        LaunchConfiguration('front_realsense_tilt_axis_z'),
        '0.0',
        '0.0',
        '0.0',
    )
    front_realsense_mount_tf = _static_tf_node(
        'go2w_front_realsense_mount_static_tf',
        front_realsense_condition,
        LaunchConfiguration('front_realsense_tilt_axis_frame'),
        LaunchConfiguration('front_realsense_mount_frame'),
        LaunchConfiguration('front_realsense_mount_x'),
        LaunchConfiguration('front_realsense_mount_y'),
        LaunchConfiguration('front_realsense_mount_z'),
        LaunchConfiguration('front_realsense_mount_roll'),
        LaunchConfiguration('front_realsense_pitch'),
        LaunchConfiguration('front_realsense_mount_yaw'),
    )
    front_realsense_body_tf = _static_tf_node(
        'go2w_front_realsense_body_static_tf',
        front_realsense_condition,
        LaunchConfiguration('front_realsense_mount_frame'),
        LaunchConfiguration('front_realsense_body_frame'),
        LaunchConfiguration('front_realsense_body_x'),
        LaunchConfiguration('front_realsense_body_y'),
        LaunchConfiguration('front_realsense_body_z'),
        LaunchConfiguration('front_realsense_body_roll'),
        LaunchConfiguration('front_realsense_body_pitch'),
        LaunchConfiguration('front_realsense_body_yaw'),
    )
    front_realsense_sensor_tf = _static_tf_node(
        'go2w_front_realsense_sensor_static_tf',
        front_realsense_condition,
        LaunchConfiguration('front_realsense_body_frame'),
        LaunchConfiguration('front_realsense_frame'),
        LaunchConfiguration('front_realsense_sensor_x'),
        LaunchConfiguration('front_realsense_sensor_y'),
        LaunchConfiguration('front_realsense_sensor_z'),
        '0.0',
        '0.0',
        '0.0',
    )

    # Compatibility bridge for RealSense wrappers/services that publish
    # camera_link-based optical frames. This does not change the thesis URDF
    # geometry or rename the canonical front_realsense frame.
    realsense_camera_link_alias_tf = _static_tf_node(
        'go2w_realsense_camera_link_alias_static_tf',
        IfCondition(
            LaunchConfiguration('publish_realsense_camera_link_alias')
        ),
        'front_realsense',
        'camera_link',
        '0.0',
        '0.0',
        '0.0',
        '0.0',
        '0.0',
        '0.0',
    )

    # Experimental visual alignment for /utlidar/cloud only. This is not a
    # verified final physical sensor calibration.
    lidar_tf = Node(
        condition=IfCondition(LaunchConfiguration('publish_lidar_tf')),
        package='tf2_ros',
        executable='static_transform_publisher',
        name='go2w_experimental_lidar_static_tf',
        arguments=[
            '--x',
            LaunchConfiguration('lidar_x'),
            '--y',
            LaunchConfiguration('lidar_y'),
            '--z',
            LaunchConfiguration('lidar_z'),
            '--roll',
            LaunchConfiguration('lidar_roll'),
            '--pitch',
            LaunchConfiguration('lidar_pitch'),
            '--yaw',
            LaunchConfiguration('lidar_yaw'),
            '--frame-id',
            LaunchConfiguration('lidar_parent_frame'),
            '--child-frame-id',
            LaunchConfiguration('lidar_child_frame'),
        ],
        output='screen',
    )

    lowstate_joint_states = Node(
        condition=IfCondition(
            LaunchConfiguration('publish_lowstate_joint_states')
        ),
        package='go2_bringup',
        executable='lowstate_to_joint_states',
        name='lowstate_to_joint_states',
        parameters=[
            LaunchConfiguration('joint_names_file'),
            {
                'lowstate_topic': LaunchConfiguration('lowstate_topic'),
                'use_sim_time': LaunchConfiguration('use_sim_time'),
            },
        ],
        output='screen',
    )

    odom_to_tf = Node(
        condition=IfCondition(LaunchConfiguration('publish_odom_tf')),
        package='go2_bringup',
        executable='go2w_odom_to_tf',
        name='go2w_odom_to_tf',
        parameters=[{
            'odom_topic': LaunchConfiguration('odom_topic'),
            'parent_frame': LaunchConfiguration('odom_parent_frame'),
            'child_frame': LaunchConfiguration('odom_child_frame'),
            'publish_tf': LaunchConfiguration('publish_odom_tf'),
        }],
        output='screen',
    )

    return LaunchDescription(args + [
        robot_description_tf,
        static_odom_tf,
        front_realsense_base_tf,
        front_realsense_tilt_axis_tf,
        front_realsense_mount_tf,
        front_realsense_body_tf,
        front_realsense_sensor_tf,
        realsense_camera_link_alias_tf,
        lidar_tf,
        lowstate_joint_states,
        odom_to_tf,
    ])
