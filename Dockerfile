# Build a ROS Indigo image for use on Raspberry Pi. Based on the
# instructions at http://wiki.ros.org/ROSberryPi.
#
# ROS is installed for the user 'ros' (password: 'pi'). This user has
# access to sudo. If you want to add packages, as per the wiki page,
# the build files are saved in /opt/ros-build-dir.
#
# NOTE: if building on a 256 MB Pi, this will run out of memory and
# crash unless you change the memory split to only give 16 MB (the
# minimum) to the GPU.
#
# See http://blog.xebia.com/2014/08/25/docker-on-a-raspberry-pi/ for
# Docker installation instructions on the Raspberry Pi.

FROM resin/rpi-raspbian:wheezy


RUN apt-get update && apt-get -y install \
    checkinstall \
    cmake \
    git \
    libboost-system-dev \
    libboost-thread-dev \
    libyaml-dev \
    python \
    python-dev \
    sudo \
    wget

RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu wheezy main" > /etc/apt/sources.list.d/ros-latest.list' && \
    wget https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -O - | sudo apt-key add -


# Chicken and egg problem: both setuptools and pip need to be newer
# than the ones in wheezy (but not the absolute newest)
RUN apt-get update && \
    apt-get -y install python-setuptools && \
    easy_install pip==1.2.1 && \
    pip install -U setuptools && \
    apt-get -y remove --purge --auto-remove python-setuptools


# ROS doesn't like being root; create a normal user for it
RUN useradd -m -G sudo -s /bin/bash ros && \
    echo ros:pi | chpasswd


# Initial ROS setup
RUN pip install -U rosdep rosinstall_generator wstool rosinstall && \
    rosdep init && \
    mkdir -p /opt/ros-build-dir && \
    chown ros:ros /opt/ros-build-dir

WORKDIR /opt/ros-build-dir

RUN su ros -c \
    "rosdep update && \
     mkdir ros_catkin_ws && \
     cd ros_catkin_ws && \
     rosinstall_generator ros_comm --rosdistro indigo --deps --wet-only --exclude roslisp --tar > indigo-ros_comm-wet.rosinstall && \
     wstool init -j8 src indigo-ros_comm-wet.rosinstall"

RUN su ros -c \
    "mkdir ros_catkin_ws/external_src && \
     cd ros_catkin_ws/external_src && \
     git clone https://github.com/ros/console_bridge.git && \
     cd console_bridge && \
     cmake ."


# Install missing dependencies in Raspbian
RUN cd ros_catkin_ws/external_src/console_bridge && \
    checkinstall --pkgname libconsole-bridge-dev make install

RUN cd ros_catkin_ws/external_src && \
    wget http://archive.raspbian.org/raspbian/pool/main/l/lz4/liblz4-1_0.0~r122-2_armhf.deb && \
    wget http://archive.raspbian.org/raspbian/pool/main/l/lz4/liblz4-dev_0.0~r122-2_armhf.deb && \
    dpkg -i liblz4-1_0.0~r122-2_armhf.deb liblz4-dev_0.0~r122-2_armhf.deb


# Pull in ROS dependencies. The rosdep install calls sudo internally,
# but doesn't like running as root; the seds are a workaround.
RUN sed -i $'s/%sudo\tALL=(ALL:ALL) ALL/%sudo\tALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers

RUN su ros -c \
    "cd ros_catkin_ws && \
     rosdep install --from-paths src --ignore-src --rosdistro indigo -y -r --os=debian:wheezy"

RUN sed -i $'s/%sudo\tALL=(ALL:ALL) NOPASSWD:ALL/%sudo\tALL=(ALL:ALL) ALL/g' /etc/sudoers


# Main build - this takes a long time!
RUN cd ros_catkin_ws && \
    ./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release --install-space /opt/ros/indigo


# Final configuration
RUN su ros -c "echo 'source /opt/ros/indigo/setup.bash' >> ~/.bashrc"


# Run a non-root interactive shell
CMD ["su", "-l", "ros"]
