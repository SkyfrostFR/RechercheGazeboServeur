# TIAGo Dual (TIAGo++) public simulation, ROS 1 Noetic + Gazebo Classic, plus
# rosbridge for the Unity digital twin (ROS#, ws://localhost:9090).
# Based on pal-robotics/tiago_dual_tutorials/Dockerfile, without the IDE tools.
FROM osrf/ros:noetic-desktop-full-focal

ARG REPO_WS=/tiago_dual_public_ws
RUN mkdir -p $REPO_WS/src
WORKDIR $REPO_WS

RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget ca-certificates \
    python-is-python3 python3-scipy python3-networkx python3-pip \
    python3-vcstool python3-rosinstall python3-catkin-tools python3-wstool \
    ros-noetic-actionlib-tools ros-noetic-moveit-commander \
    ros-noetic-rosbridge-server ros-noetic-image-transport-plugins \
  && rm -rf /var/lib/apt/lists/* \
  && wget -q https://raw.githubusercontent.com/pal-robotics/tiago_dual_tutorials/master/tiago_dual_public-noetic.rosinstall \
  && vcs import src < tiago_dual_public-noetic.rosinstall \
  # pal_navigation_msgs left pal_msgs on 2025-10-23 (99c5958d13) and has no
  # public repo: pin pal_msgs to the last commit that still ships it.
  && git -C src/pal_msgs checkout -q b843390cbf

ARG ROSDEP_IGNORE="urdf_test omni_drive_controller orocos_kdl pal_filters libgazebo9-dev pal_usb_utils speed_limit_node camera_calibration_files pal_moveit_plugins pal_startup_msgs pal_local_joint_control pal_pcl_points_throttle_and_filter current_limit_controller hokuyo_node dynamixel_cpp pal_moveit_capabilities pal_pcl dynamic_footprint gravity_compensation_controller pal-orbbec-openni2 pal_loc_measure pal_map_manager joint_impedance_trajectory_controller ydlidar_ros_driver"

RUN apt-get update && rosdep install --from-paths src --ignore-src -y --rosdistro noetic --skip-keys="${ROSDEP_IGNORE}" \
  && rm -rf /var/lib/apt/lists/*

RUN bash -c "source /opt/ros/noetic/setup.bash \
    && catkin build -DCATKIN_ENABLE_TESTING=0 -j 8 \
    && echo 'source $REPO_WS/devel/setup.bash' >> ~/.bashrc"

ENTRYPOINT ["bash"]
