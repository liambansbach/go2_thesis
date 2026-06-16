from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

# Nvblox debug: ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_nvblox_debug.rviz
# Robot/TF debug: ros2 launch go2_bringup go2w_debug_rviz.launch.py rviz_config:=go2w_tf_robot_debug.rviz


def generate_launch_description():
    args = [
        DeclareLaunchArgument('rviz_config', default_value='go2w_tf_robot_debug.rviz'),
        DeclareLaunchArgument('use_sim_time', default_value='false'),
        DeclareLaunchArgument('log_level', default_value='info'),
    ]

    rviz = Node(
        package='rviz2',
        executable='rviz2',
        name='go2w_debug_rviz',
        arguments=[
            '-d',
            PathJoinSubstitution([
                FindPackageShare('go2_bringup'),
                'rviz',
                LaunchConfiguration('rviz_config'),
            ]),
            '--ros-args',
            '--log-level',
            LaunchConfiguration('log_level'),
        ],
        parameters=[{'use_sim_time': LaunchConfiguration('use_sim_time')}],
        output='screen',
    )

    return LaunchDescription(args + [rviz])
