# Setup

This document describes the initial setup for the `go2_thesis` project.

Target setup:

```text
Host:      Ubuntu 24.04
Container: Ubuntu 22.04 + ROS 2 Humble
Middleware: CycloneDDS
Robot:     Unitree Go2 wheeled
```

The host only needs Docker, NVIDIA drivers/toolkit, Git, and basic development tools. ROS 2 runs inside the Docker container.

## 1. Install basic host tools

```bash
sudo apt update
sudo apt install -y \
  git curl wget build-essential \
  python3-pip python3-venv \
  net-tools iputils-ping \
  x11-xserver-utils
```

## 2. Install Docker if missing

Check first:

```bash
docker --version
```

If Docker is missing, install Docker Engine:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

docker run hello-world
```

## 3. Install NVIDIA Container Toolkit if GPU support is needed

Check first:

```bash
nvidia-smi
```

If `nvidia-smi` fails, fix the host NVIDIA driver first. Docker GPU support only works if the host driver works.

Install the NVIDIA Container Toolkit:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Test GPU access in Docker:

```bash
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
```

## 4. Clone the repository

```bash
cd ~/Desktop/projects
git clone https://github.com/liambansbach/go2_thesis.git
cd go2_thesis
```

If the repository already exists:

```bash
cd ~/Desktop/projects/go2_thesis
git pull
```

## 5. Build and start the ROS 2 container

Build the Docker image:

```bash
./scripts/build.sh
```

Start the container:

```bash
./scripts/run.sh
```

Inside the container, verify ROS 2:

```bash
echo $ROS_DISTRO
echo $RMW_IMPLEMENTATION
which ros2
ros2 topic list
```

Expected:

```text
humble
rmw_cyclonedds_cpp
/opt/ros/humble/bin/ros2
/parameter_events
/rosout
```

## 6. Build the ROS 2 workspace

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

Check custom packages:

```bash
ros2 pkg list | grep -E "go2_bringup|semantic_risk_node|risk_map_projection"
```

## 7. Test ROS 2 communication

Terminal 1, inside container:

```bash
ros2 run demo_nodes_cpp talker
```

Terminal 2, open another container shell or even from outside the container if you have a different ROS 2 setup:

```bash
./scripts/shell.sh
ros2 run demo_nodes_py listener
```

If the listener receives messages, the ROS 2 container setup works.

## 8. Prepare Ethernet for Go2 testing

Check available interfaces on the host:

```bash
ip -br link
```

Example output:

```text
lo       UNKNOWN
eno1     DOWN
wlo1     UP
docker0  DOWN
```

Use the wired Ethernet interface for the Go2. In this example, use `eno1`.
Do not use:

```text
lo       loopback
wlo1     Wi-Fi
docker0  Docker bridge
```

Configure the Ethernet interface:

```bash
./scripts/setup_go2_ethernet.sh eno1
```

Start the container with the Go2 network interface:

```bash
ROS_NET_IFACE=eno1 ./scripts/run.sh
```

Inside the container:

```bash
./scripts/robot_net_check.sh
ros2 topic list
```
