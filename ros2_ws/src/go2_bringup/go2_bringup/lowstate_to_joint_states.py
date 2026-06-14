"""Publish JointState messages from Unitree LowState for visualization.

This node is read-only: it subscribes to Unitree LowState and publishes
``sensor_msgs/JointState``. It never publishes robot commands.

Warning:
    The default LowState motor order must be verified on the real Go2-W before
    using this node for accurate visualization, kinematics, or analysis. The
    ``joint_names`` parameter is intentionally configurable so the order can be
    corrected without editing code.
"""

import sys

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState

try:
    from unitree_go.msg import LowState
except ImportError as exc:
    LowState = None
    LOWSTATE_IMPORT_ERROR = exc
else:
    LOWSTATE_IMPORT_ERROR = None


DEFAULT_JOINT_NAMES = [
    'FL_hip_joint',
    'FL_thigh_joint',
    'FL_calf_joint',
    'FR_hip_joint',
    'FR_thigh_joint',
    'FR_calf_joint',
    'RL_hip_joint',
    'RL_thigh_joint',
    'RL_calf_joint',
    'RR_hip_joint',
    'RR_thigh_joint',
    'RR_calf_joint',
    'FL_foot_joint',
    'FR_foot_joint',
    'RL_foot_joint',
    'RR_foot_joint',
]


class LowStateToJointStates(Node):
    """Convert the first LowState motor states to JointState."""

    def __init__(self):
        super().__init__('lowstate_to_joint_states')

        if LowState is None:
            raise RuntimeError(
                'unitree_go.msg.LowState is unavailable. Build and source the '
                'Unitree ROS 2 overlay before enabling '
                'publish_lowstate_joint_states.'
            ) from LOWSTATE_IMPORT_ERROR

        self.declare_parameter('lowstate_topic', '/lowstate')
        self.declare_parameter('joint_names', DEFAULT_JOINT_NAMES)

        self.lowstate_topic = (
            self.get_parameter('lowstate_topic')
            .get_parameter_value()
            .string_value
        )
        self.joint_names = list(
            self.get_parameter('joint_names')
            .get_parameter_value()
            .string_array_value
        )
        if not self.joint_names:
            self.joint_names = DEFAULT_JOINT_NAMES

        self._warned_short_motor_state = False
        self._warned_joint_count = False

        if len(self.joint_names) != len(DEFAULT_JOINT_NAMES):
            self.get_logger().warn(
                'joint_names has %d entries; the Go2-W default has %d. '
                'Publishing the overlapping motor/joint subset.'
                % (len(self.joint_names), len(DEFAULT_JOINT_NAMES))
            )

        self.publisher = self.create_publisher(JointState, '/joint_states', 10)
        self.subscription = self.create_subscription(
            LowState,
            self.lowstate_topic,
            self._lowstate_callback,
            10,
        )

        self.get_logger().warn(
            'LowState motor order is unverified for this robot. Use this node '
            'for visualization only until joint_names order is confirmed.'
        )
        self.get_logger().info(
            'Publishing /joint_states from %s without sending robot commands.'
            % self.lowstate_topic
        )

    def _lowstate_callback(self, msg):
        motor_state = list(getattr(msg, 'motor_state', []))
        count = min(len(motor_state), len(self.joint_names))

        if len(motor_state) < len(self.joint_names):
            if not self._warned_short_motor_state:
                self.get_logger().warn(
                    'LowState motor_state has %d entries but %d joint names '
                    'are configured; publishing only available entries.'
                    % (len(motor_state), len(self.joint_names))
                )
                self._warned_short_motor_state = True

        if count != len(DEFAULT_JOINT_NAMES) and not self._warned_joint_count:
            self.get_logger().warn(
                'Publishing %d joints. Expected 16 for the default Go2-W URDF.'
                % count
            )
            self._warned_joint_count = True

        joint_state = JointState()
        joint_state.header.stamp = self._stamp_from_msg_or_clock(msg)
        joint_state.name = self.joint_names[:count]
        joint_state.position = [
            float(getattr(state, 'q', 0.0)) for state in motor_state[:count]
        ]
        joint_state.velocity = [
            float(getattr(state, 'dq', 0.0)) for state in motor_state[:count]
        ]
        joint_state.effort = [
            float(getattr(state, 'tau_est', 0.0))
            for state in motor_state[:count]
        ]

        self.publisher.publish(joint_state)

    def _stamp_from_msg_or_clock(self, msg):
        header = getattr(msg, 'header', None)
        stamp = getattr(header, 'stamp', None)
        if stamp is not None and (stamp.sec != 0 or stamp.nanosec != 0):
            return stamp
        return self.get_clock().now().to_msg()


def main(args=None):
    rclpy.init(args=args)
    try:
        node = LowStateToJointStates()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        rclpy.shutdown()
        raise SystemExit(1)

    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
