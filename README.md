Docker image of ROS Indigo for the Raspberry Pi
===============================================

To build, run `docker build .` on the Pi. This will take a long time!

Based on the instructions at http://wiki.ros.org/ROSberryPi. See http://blog.xebia.com/2014/08/25/docker-on-a-raspberry-pi/ for Docker installation instructions on the Raspberry Pi.

ROS is installed for the user 'ros' (default password: 'pi'). This user has access to sudo. If you want to add packages, as per the wiki page, the build files are saved in /opt/ros-build-dir.

NOTE: if building on a 256 MB Pi, the build will run out of memory and crash unless you change the memory split to only give 16 MB (the minimum) to the GPU.
