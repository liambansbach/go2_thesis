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
    rviz_config = LaunchConfiguration('rviz_config')
    use_joint_state_gui = LaunchConfiguration('use_joint_state_gui')
    use_rviz = LaunchConfiguration('use_rviz')
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

    joint_state_publisher_gui = Node(
        condition=IfCondition(use_joint_state_gui),
        package='joint_state_publisher_gui',
        executable='joint_state_publisher_gui',
        name='hexlab_go2w_joint_state_publisher_gui',
        parameters=[
            robot_description,
            {'use_sim_time': use_sim_time},
        ],
        output='screen',
    )

    rviz = Node(
        condition=IfCondition(use_rviz),
        package='rviz2',
        executable='rviz2',
        name='hexlab_go2w_rviz',
        arguments=['-d', rviz_config],
        parameters=[{'use_sim_time': use_sim_time}],
        output='screen',
    )

    return LaunchDescription([
        DeclareLaunchArgument('robot_ns', default_value='go2_unit_46273'),
        DeclareLaunchArgument('use_rviz', default_value='true'),
        DeclareLaunchArgument('use_joint_state_gui', default_value='true'),
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument(
            'rviz_config',
            default_value=PathJoinSubstitution([
                FindPackageShare('hexlab_go2w_description'),
                'rviz',
                'hexlab_go2w_model_base.rviz',
            ]),
        ),
        *_hexlab_model_environment(robot_ns),
        robot_state_publisher,
        joint_state_publisher_gui,
        rviz,
    ])
