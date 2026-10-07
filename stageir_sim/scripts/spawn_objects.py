#!/usr/bin/env python3
"""Spawn the test objects listed under ~objects (config/objects.yaml) into Gazebo.

Each object becomes a one-link SDF model with high-friction contacts, so the PAL
grippers can hold it. The list stays on the parameter server: the Unity client
reads it through rosapi to draw the same objects.
"""
import rospy
from gazebo_msgs.srv import SpawnModel
from geometry_msgs.msg import Pose

SURFACE = """<surface>
  <friction><ode><mu>10</mu><mu2>10</mu2></ode></friction>
  <contact><ode><kp>1e6</kp><kd>100</kd><max_vel>0.1</max_vel><min_depth>0.001</min_depth></ode></contact>
</surface>"""


def geometry(obj):
    shape = obj['shape']
    if shape == 'box':
        return '<box><size>%g %g %g</size></box>' % tuple(obj['size'])
    if shape == 'cylinder':
        return '<cylinder><radius>%g</radius><length>%g</length></cylinder>' % (
            obj['radius'], obj['length'])
    if shape == 'sphere':
        return '<sphere><radius>%g</radius></sphere>' % obj['radius']
    raise ValueError('unknown shape %r for %s' % (shape, obj['name']))


def inertia(obj, m):
    """Solid-body inertia about the centre of mass."""
    shape = obj['shape']
    if shape == 'box':
        x, y, z = obj['size']
        return (m * (y * y + z * z) / 12, m * (x * x + z * z) / 12, m * (x * x + y * y) / 12)
    if shape == 'cylinder':
        r, h = obj['radius'], obj['length']
        i = m * (3 * r * r + h * h) / 12
        return (i, i, m * r * r / 2)
    i = 2 * m * obj['radius'] ** 2 / 5
    return (i, i, i)


def sdf(obj):
    geom = geometry(obj)
    r, g, b = obj.get('colour', [0.7, 0.7, 0.7])
    static = bool(obj.get('static', False))
    inertial = ''
    if not static:
        m = float(obj.get('mass', 0.1))
        ixx, iyy, izz = inertia(obj, m)
        inertial = ('<inertial><mass>%g</mass><inertia><ixx>%g</ixx><iyy>%g</iyy><izz>%g</izz>'
                    '<ixy>0</ixy><ixz>0</ixz><iyz>0</iyz></inertia></inertial>' % (m, ixx, iyy, izz))
    return """<?xml version="1.0"?>
<sdf version="1.6"><model name="{name}"><static>{static}</static><link name="link">
  {inertial}
  <collision name="collision"><geometry>{geom}</geometry>{surface}</collision>
  <visual name="visual"><geometry>{geom}</geometry>
    <material><ambient>{r} {g} {b} 1</ambient><diffuse>{r} {g} {b} 1</diffuse></material>
  </visual>
</link></model></sdf>""".format(name=obj['name'], static=str(static).lower(), inertial=inertial,
                                 geom=geom, surface=SURFACE, r=r, g=g, b=b)


def main():
    rospy.init_node('spawn_objects')
    objects = rospy.get_param('~objects', [])
    rospy.wait_for_service('/gazebo/spawn_sdf_model')
    spawn = rospy.ServiceProxy('/gazebo/spawn_sdf_model', SpawnModel)
    for obj in objects:
        pose = Pose()
        pose.position.x, pose.position.y, pose.position.z = obj['position']
        pose.orientation.w = 1.0
        try:
            res = spawn(obj['name'], sdf(obj), '', pose, 'world')
        except (rospy.ServiceException, ValueError) as e:
            rospy.logerr('spawn %s failed: %s', obj.get('name'), e)
            continue
        if res.success:
            rospy.loginfo('spawned %s', obj['name'])
        else:
            rospy.logerr('spawn %s failed: %s', obj['name'], res.status_message)


if __name__ == '__main__':
    main()
