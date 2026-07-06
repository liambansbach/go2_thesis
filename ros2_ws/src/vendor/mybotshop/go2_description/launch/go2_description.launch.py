#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Software License Agreement (BSD)
#
# @author    Salman Omar Sohail <support@mybotshop.de>
# @copyright (c) 2024, MYBOTSHOP GmbH, Inc., All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of MYBOTSHOP GmbH nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Redistribution and use in source and binary forms, with or without
# modification, is not permitted without the express permission
# of MYBOTSHOP GmbH.

import os

from launch import LaunchDescription
from launch.substitutions import Command, FindExecutable, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare
from launch.actions import SetEnvironmentVariable


def generate_launch_description():

    go2_control_domain_id = SetEnvironmentVariable('ROS_DOMAIN_ID', '10')

    nsp = os.environ.get('ROBOT_NS', 'go2_unit_001')

    rmp = [
        ('/tf', 'tf'),
        ('/tf_static', 'tf_static'),
        ('/joint_states', 'joint_states'),
        ('/robot_description', 'robot_description'),
    ]

    robot_description_content = Command(
        [
            PathJoinSubstitution([FindExecutable(name="xacro")]),
            " ",
            PathJoinSubstitution(
                [FindPackageShare("go2_description"), "xacro", "robot.xacro"]
            ),
            " ",
            "namespace:=",
            nsp,
        ]
    )

    robot_description = {"robot_description": robot_description_content}

    node_robot_state_publisher = Node(
        namespace=nsp,
        remappings=rmp,
        package="robot_state_publisher",
        executable="robot_state_publisher",
        output="screen",
        parameters=[robot_description, {"publish_frequency": 30.0}],
    )

    node_joint_state_publisher = Node(
        namespace=nsp,
        remappings=rmp,
        name="go2_joint_state_merger",
        package="joint_state_publisher",
        executable="joint_state_publisher",
        output="screen",
        parameters=[
            {'rate': 50},
            {'source_list': [
                f'/{nsp}/platform/joint_states',
                f'/{nsp}/d1/joint_states',
                f'/{nsp}/zt30/joint_states',
                f'/{nsp}/open_manipulator/corrected_joint_states',
            ]}
        ],
    )

    ld = LaunchDescription()

    ld.add_action(go2_control_domain_id)
    ld.add_action(node_robot_state_publisher)
    ld.add_action(node_joint_state_publisher)

    return ld
