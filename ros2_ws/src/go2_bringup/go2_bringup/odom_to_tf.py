import rclpy
from geometry_msgs.msg import TransformStamped
from nav_msgs.msg import Odometry
from rclpy.node import Node
from tf2_ros import TransformBroadcaster


class OdomToTf(Node):
    """Read-only bridge from nav_msgs/Odometry pose to TF."""

    def __init__(self):
        super().__init__('go2w_odom_to_tf')

        self.declare_parameter('odom_topic', '/utlidar/robot_odom')
        self.declare_parameter('parent_frame', '')
        self.declare_parameter('child_frame', '')
        self.declare_parameter('publish_tf', False)

        self.odom_topic = (
            self.get_parameter('odom_topic').get_parameter_value().string_value
        )
        self.parent_frame = (
            self.get_parameter('parent_frame').get_parameter_value().string_value
        )
        self.child_frame = (
            self.get_parameter('child_frame').get_parameter_value().string_value
        )
        self.publish_tf = (
            self.get_parameter('publish_tf').get_parameter_value().bool_value
        )

        self._warned_missing_parent = False
        self._warned_disabled = False

        self.tf_broadcaster = TransformBroadcaster(self)
        self.subscription = self.create_subscription(
            Odometry,
            self.odom_topic,
            self._odom_callback,
            10,
        )

        if self.publish_tf:
            self.get_logger().info(
                f'Publishing TF from odometry topic {self.odom_topic}'
            )
        else:
            self.get_logger().warn(
                'publish_tf is false; subscribed for validation but not '
                'broadcasting TF.'
            )

    def _odom_callback(self, msg):
        if not self.publish_tf:
            if not self._warned_disabled:
                self.get_logger().warn(
                    'Received odometry, but publish_tf is false. No TF sent.'
                )
                self._warned_disabled = True
            return

        parent_frame = self.parent_frame or msg.header.frame_id
        child_frame = self.child_frame or msg.child_frame_id or 'base_link'

        if not parent_frame:
            if not self._warned_missing_parent:
                self.get_logger().warn(
                    'No parent_frame parameter and odometry header.frame_id is '
                    'empty; skipping TF until a parent frame is available.'
                )
                self._warned_missing_parent = True
            return

        transform = TransformStamped()
        transform.header.stamp = msg.header.stamp
        transform.header.frame_id = parent_frame
        transform.child_frame_id = child_frame
        transform.transform.translation.x = msg.pose.pose.position.x
        transform.transform.translation.y = msg.pose.pose.position.y
        transform.transform.translation.z = msg.pose.pose.position.z
        transform.transform.rotation = msg.pose.pose.orientation

        self.tf_broadcaster.sendTransform(transform)


def main(args=None):
    rclpy.init(args=args)
    node = OdomToTf()
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
