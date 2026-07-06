from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, SetEnvironmentVariable
from launch.conditions import IfCondition
from launch.substitutions import Command, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def _hexlab_model_environment(robot_ns):
    return [
        SetEnvironmentVariable('GO2_FOOT', '0'),
        SetEnvironmentVariable('GO2_WHEELED', '1'),
        SetEnvironmentVariable('GO2_OPEN_MANIPULATOR', '0'),
        SetEnvironmentVariable('GO2_REALSENSE', '0'),
        SetEnvironmentVariable('GO2_REALSENSE_WRIST', '0'),
        SetEnvironmentVariable('GO2_ZT30', '0'),
        SetEnvironmentVariable('GO2_D1_CUSTOM', '0'),
        SetEnvironmentVariable('GO2_D1_EXPORTER', '0'),
        SetEnvironmentVariable('GO2_COMPUTER_DOCK', '1'),
        SetEnvironmentVariable('HEXLAB_FRONT_REALSENSE_D456', '1'),
        SetEnvironmentVariable('ROBOT_NS', robot_ns),
    ]


def generate_launch_description():
    robot_ns = LaunchConfiguration('robot_ns')
    use_joint_state_relay = LaunchConfiguration('use_joint_state_relay')
    joint_state_input_topic = LaunchConfiguration('joint_state_input_topic')
    joint_state_output_topic = LaunchConfiguration('joint_state_output_topic')
    use_sim_time = LaunchConfiguration('use_sim_time')

    xacro_file = PathJoinSubstitution([
        FindPackageShare('hexlab_go2w_description'),
        'xacro',
        'go2w_hexlab.urdf.xacro',
    ])

    robot_description = {
        'robot_description': Command([
            'xacro ',
            xacro_file,
            ' namespace:=',
            robot_ns,
        ])
    }

    robot_state_publisher = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        name='hexlab_go2w_robot_state_publisher',
        parameters=[
            robot_description,
            {'use_sim_time': use_sim_time},
        ],
        output='screen',
    )

    joint_state_relay = Node(
        condition=IfCondition(use_joint_state_relay),
        package='hexlab_go2w_bringup',
        executable='joint_state_relay',
        name='hexlab_go2w_joint_state_relay',
        parameters=[{
            'input_topic': joint_state_input_topic,
            'output_topic': joint_state_output_topic,
            'restamp': False,
            'use_sim_time': use_sim_time,
        }],
        output='screen',
    )

    return LaunchDescription([
        DeclareLaunchArgument('robot_ns', default_value='go2_unit_46273'),
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument('use_joint_state_relay', default_value='true'),
        DeclareLaunchArgument(
            'joint_state_input_topic',
            default_value='/go2_unit_46273/platform/joint_states',
        ),
        DeclareLaunchArgument(
            'joint_state_output_topic',
            default_value='/joint_states',
        ),
        *_hexlab_model_environment(robot_ns),
        robot_state_publisher,
        joint_state_relay,
    ])
