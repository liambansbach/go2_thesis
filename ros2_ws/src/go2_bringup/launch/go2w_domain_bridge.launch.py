from hashlib import sha256
from pathlib import Path

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def _replace_top_level_scalar(text, key, value):
    replacement = f'{key}: {value}'
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.startswith(f'{key}:'):
            lines[index] = replacement
            return '\n'.join(lines) + '\n'
    return replacement + '\n' + text


def _domain_bridge_node(context, *args, **kwargs):
    bridge_config = Path(LaunchConfiguration('bridge_config').perform(context))
    from_domain = LaunchConfiguration('from_domain').perform(context)
    to_domain = LaunchConfiguration('to_domain').perform(context)

    config_text = bridge_config.read_text(encoding='utf-8')
    config_text = _replace_top_level_scalar(
        config_text,
        'from_domain',
        from_domain,
    )
    config_text = _replace_top_level_scalar(config_text, 'to_domain', to_domain)

    digest = sha256(
        f'{bridge_config}:{from_domain}:{to_domain}:{config_text}'.encode()
    ).hexdigest()[:12]
    generated_dir = Path('/tmp/go2w_domain_bridge')
    generated_dir.mkdir(parents=True, exist_ok=True)
    generated_config = generated_dir / f'go2w_bridge_{digest}.yaml'
    generated_config.write_text(config_text, encoding='utf-8')

    return [
        Node(
            package='domain_bridge',
            executable='domain_bridge',
            name='go2w_domain_bridge',
            arguments=[str(generated_config)],
            output='screen',
        )
    ]


def generate_launch_description():
    default_bridge_config = PathJoinSubstitution([
        FindPackageShare('go2_bringup'),
        'config',
        'domain_bridge',
        'go2w_domain10_to_domain0.yaml',
    ])

    args = [
        DeclareLaunchArgument(
            'from_domain',
            default_value='10',
            description='Vendor/MyBotShop ROS_DOMAIN_ID to read from.',
        ),
        DeclareLaunchArgument(
            'to_domain',
            default_value='0',
            description='Canonical thesis ROS_DOMAIN_ID to publish into.',
        ),
        DeclareLaunchArgument(
            'bridge_config',
            default_value=default_bridge_config,
            description='domain_bridge YAML config to launch.',
        ),
    ]

    return LaunchDescription(args + [OpaqueFunction(function=_domain_bridge_node)])
