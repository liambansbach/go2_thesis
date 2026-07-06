from glob import glob
from setuptools import find_packages, setup


package_name = 'hexlab_go2w_bringup'

setup(
    name=package_name,
    version='0.0.1',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='HEXLab',
    maintainer_email='TODO@example.com',
    description=(
        'Read-only HEXLab Go2-W state bringup for live Jetson/domain-10 '
        'visualization.'
    ),
    license='TODO',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'joint_state_relay = hexlab_go2w_bringup.joint_state_relay:main',
        ],
    },
)
