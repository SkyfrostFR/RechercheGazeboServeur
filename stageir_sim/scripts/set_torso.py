#!/usr/bin/env python3
"""Move the torso to ~height (m) once its controller is up, then exit.

The Unity twin has no torso joint: its upper body is fixed at the height of the URDF it
was generated from. Gazebo's torso is put at that height so the arms, and what they
touch, are at the same place in both. The simulated torso sags about 1 cm under its
own weight (position controller steady-state error), so the command is corrected from
the measured position a few times.
"""
import rospy
from control_msgs.msg import JointTrajectoryControllerState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint


def main():
    rospy.init_node('set_torso')
    height = float(rospy.get_param('~height', 0.0))
    rospy.wait_for_message('/torso_controller/state', JointTrajectoryControllerState)
    pub = rospy.Publisher('/torso_controller/command', JointTrajectory, queue_size=1, latch=True)
    rospy.sleep(1.0)
    command = height
    for _ in range(4):
        traj = JointTrajectory(joint_names=['torso_lift_joint'])
        traj.points.append(JointTrajectoryPoint(positions=[command], time_from_start=rospy.Duration(2.0)))
        pub.publish(traj)
        rospy.sleep(4.0)
        actual = rospy.wait_for_message('/torso_controller/state', JointTrajectoryControllerState).actual.positions[0]
        if abs(actual - height) < 0.002:
            break
        command += height - actual
    rospy.loginfo('torso -> %.3f m (commanded %.3f)', actual, command)
    rospy.sleep(1.0)


if __name__ == '__main__':
    main()
