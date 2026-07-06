"""Read-only JointState relay for live Go2-W visualization."""

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState


class JointStateRelay(Node):
    """Republish vendor JointState messages without synthesizing state."""

    def __init__(self):
        super().__init__('hexlab_go2w_joint_state_relay')

        self.declare_parameter(
            'input_topic',
            '/go2_unit_46273/platform/joint_states',
        )
        self.declare_parameter('output_topic', '/joint_states')
        self.declare_parameter('restamp', False)

        self.input_topic = (
            self.get_parameter('input_topic')
            .get_parameter_value()
            .string_value
        )
        self.output_topic = (
            self.get_parameter('output_topic')
            .get_parameter_value()
            .string_value
        )
        self.restamp = (
            self.get_parameter('restamp')
            .get_parameter_value()
            .bool_value
        )

        self.publisher = self.create_publisher(
            JointState,
            self.output_topic,
            10,
        )
        self.subscription = self.create_subscription(
            JointState,
            self.input_topic,
            self._joint_state_callback,
            10,
        )

        self.get_logger().info(
            'Relaying JointState messages from %s to %s; restamp=%s'
            % (self.input_topic, self.output_topic, self.restamp)
        )
        self.get_logger().info(
            'This node is read-only and never publishes robot commands.'
        )

    def _joint_state_callback(self, msg):
        if self.restamp:
            msg.header.stamp = self.get_clock().now().to_msg()
        self.publisher.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = JointStateRelay()
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
