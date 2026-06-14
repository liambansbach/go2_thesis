from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

# Robot description TF:
# ros2 launch go2_bringup go2w_tf.launch.py publish_robot_description_tf:=true
#
# Offline fake static odom TF:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_robot_description_tf:=true publish_static_odom_tf:=true
#
# Rough camera TF fallback only, when no robot description/camera TF is
# available:
# ros2 launch go2_bringup go2w_tf.launch.py \
#   publish_camera_tf:=true camera_x:=0.25 camera_y:=0.0 camera_z:=0.18
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


def generate_launch_description():
    args = [
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument(
            'publish_robot_description_tf',
            default_value='false',
            description=(
                'Publish fixed/movable TF from the installed Go2-W URDF.'
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
                'Publish a fake static identity odom->base transform for '
                'offline bag/RViz/Nvblox sanity checks only.'
            ),
        ),
        DeclareLaunchArgument('odom_frame', default_value='odom'),
        DeclareLaunchArgument('base_frame', default_value='base'),
        DeclareLaunchArgument(
            'publish_lowstate_joint_states',
            default_value='false',
            description=(
                'Publish /joint_states from Unitree LowState for '
                'visualization. Requires the Unitree message overlay.'
            ),
        ),
        DeclareLaunchArgument('lowstate_topic', default_value='/lowstate'),
        DeclareLaunchArgument('publish_camera_tf', default_value='false'),
        DeclareLaunchArgument('camera_parent_frame', default_value='base'),
        DeclareLaunchArgument(
            'camera_child_frame',
            default_value='camera_link',
        ),
        DeclareLaunchArgument('camera_x', default_value='0.32'),
        DeclareLaunchArgument('camera_y', default_value='0.0'),
        DeclareLaunchArgument('camera_z', default_value='0.1'),
        DeclareLaunchArgument('camera_roll', default_value='0.0'),
        DeclareLaunchArgument('camera_pitch', default_value='0.05'),
        DeclareLaunchArgument('camera_yaw', default_value='0.0'),
        DeclareLaunchArgument(
            'publish_lidar_tf',
            default_value='false',
            description=(
                'Publish experimental base->utlidar_lidar static TF for '
                'offline visual alignment only.'
            ),
        ),
        DeclareLaunchArgument('lidar_parent_frame', default_value='base'),
        DeclareLaunchArgument(
            'lidar_child_frame',
            default_value='utlidar_lidar',
        ),
        DeclareLaunchArgument('lidar_x', default_value='0.0'),
        DeclareLaunchArgument('lidar_y', default_value='0.0'),
        DeclareLaunchArgument('lidar_z', default_value='0.0'),
        DeclareLaunchArgument('lidar_roll', default_value='-2.913'),
        DeclareLaunchArgument('lidar_pitch', default_value='-0.13'),
        DeclareLaunchArgument('lidar_yaw', default_value='-1.075'),
        DeclareLaunchArgument('publish_odom_tf', default_value='false'),
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

    # Fake/static identity TF for offline replay sanity checks only. Do not use
    # this for real moving-map evaluation; Nvblox needs real dynamic odom.
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

    # Rough fallback only. Prefer publish_robot_description_tf with the Go2-W
    # URDF, plus RealSense-provided optical-frame TF from the bag/driver.
    camera_tf = Node(
        condition=IfCondition(LaunchConfiguration('publish_camera_tf')),
        package='tf2_ros',
        executable='static_transform_publisher',
        name='go2w_realsense_d456_static_tf',
        arguments=[
            '--x',
            LaunchConfiguration('camera_x'),
            '--y',
            LaunchConfiguration('camera_y'),
            '--z',
            LaunchConfiguration('camera_z'),
            '--roll',
            LaunchConfiguration('camera_roll'),
            '--pitch',
            LaunchConfiguration('camera_pitch'),
            '--yaw',
            LaunchConfiguration('camera_yaw'),
            '--frame-id',
            LaunchConfiguration('camera_parent_frame'),
            '--child-frame-id',
            LaunchConfiguration('camera_child_frame'),
        ],
        output='screen',
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
        camera_tf,
        lidar_tf,
        lowstate_joint_states,
        odom_to_tf,
    ])
