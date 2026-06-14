# Setup

First-time setup for the `go2_thesis` Go2-W ROS 2 Docker workspace.

Target setup:

```text
Host:      Ubuntu 24.04
Container: Ubuntu 22.04 + ROS 2 Humble
Middleware: CycloneDDS
Robot:     Unitree Go2-W
```

ROS 2 runs inside Docker. The host needs Docker, NVIDIA GPU support if using Nvblox, Git, and basic development tools.

## 1. Host Tools

```bash
sudo apt update
sudo apt install -y \
  git curl wget build-essential \
  python3-pip python3-venv \
  iproute2 net-tools iputils-ping \
  x11-xserver-utils
```

## 2. Docker

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

## 3. NVIDIA Container Toolkit

Nvblox needs GPU access. Check the host driver first:

```bash
nvidia-smi
```

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

Test GPU passthrough:

```bash
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
```

## 4. Repository

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

## 5. Build And Start Container

```bash
./scripts/docker/build.sh
./scripts/docker/run.sh
```

Use plain `./scripts/docker/run.sh` for offline builds, bag replay, and local checks. Live Go2-W Ethernet mode is covered in `docs/workflow.md` and `scripts/README_scripts.md`.

Inside the container:

```bash
echo $ROS_DISTRO
echo $RMW_IMPLEMENTATION
which ros2
ros2 topic list
```

Expected basics:

```text
humble
rmw_cyclonedds_cpp
/opt/ros/humble/bin/ros2
```

## 6. Build ROS Workspace

Inside the container:

```bash
cd /workspaces/go2_thesis/ros2_ws
colcon build
source install/setup.bash
```

Check project packages:

```bash
ros2 pkg list | grep -E "go2_bringup|go2w_description|semantic_risk_node|risk_map_projection"
```

## 7. Local ROS Check

Terminal 1:

```bash
ros2 run demo_nodes_cpp talker
```

Terminal 2:

```bash
./scripts/docker/shell.sh
ros2 run demo_nodes_py listener
```

If the listener receives messages, the local ROS 2 container setup is working.
