#!/usr/bin/env python3
"""Convert Gazebo's 32FC1 depth (metres) into the real TIAGo's 16UC1 (millimetres).

NaN / inf / out-of-range pixels become 0, which the real sensor and the Unity
TiagoDepthSubscriber use for "no return".
"""
import numpy as np
import rospy
from cv_bridge import CvBridge
from sensor_msgs.msg import Image

MAX_MM = np.iinfo(np.uint16).max


def main():
    rospy.init_node('depth_to_mm')
    bridge = CvBridge()
    pub = rospy.Publisher('depth_mm', Image, queue_size=1)

    def on_depth(msg):
        if pub.get_num_connections() == 0:
            return
        metres = bridge.imgmsg_to_cv2(msg, desired_encoding='32FC1')
        mm = np.nan_to_num(metres * 1000.0, nan=0.0, posinf=0.0, neginf=0.0)
        mm[(mm < 0) | (mm > MAX_MM)] = 0
        out = bridge.cv2_to_imgmsg(mm.astype(np.uint16), encoding='16UC1')
        out.header = msg.header
        pub.publish(out)

    rospy.Subscriber('depth_in', Image, on_depth, queue_size=1, buff_size=2 ** 24)
    rospy.spin()


if __name__ == '__main__':
    main()
