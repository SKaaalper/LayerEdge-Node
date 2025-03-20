#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run this script as the root user\e[0m"
  exit 1
fi

clear
echo -e "\e[1;34m==========================================\e[0m"
echo -e "\e[1;32m=          Layer Edge Node           =\e[0m"
echo -e "\e[1;36m=  https://t.me/KatayanAirdropGnC    =\e[0m"
echo -e "\e[1;33m=           Batang Eds               =\e[0m"
echo -e "\e[1;34m==========================================\e[0m\n"

WORK_DIR="/root/light-node"
echo -e "\e[1;35mWorking directory:\e[0m $WORK_DIR"

echo -e "\e[1;34mInstalling basic tools (git, curl, netcat)...\e[0m"
apt update
apt install -y git curl netcat-openbsd

if [ -d "$WORK_DIR" ]; then
  echo -e "\e[1;33mDetected that $WORK_DIR already exists, attempting to update...\e[0m"
  cd $WORK_DIR
  git pull
else
  echo -e "\e[1;32mCloning the Layer Edge Light Node repository...\e[0m"
  git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR
  cd $WORK_DIR
fi
if [ $? -ne 0 ]; then
  echo -e "\e[31mFailed to clone or update the repository, please check your network or permissions\e[0m"
  exit 1
fi

if ! command -v rustc &> /dev/null; then
  echo -e "\e[1;32mInstalling Rust...\e[0m"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi
rust_version=$(rustc --version)
echo -e "\e[1;35mCurrent Rust version:\e[0m $rust_version"

echo -e "\e[1;32mInstalling the RISC0 toolchain manager (rzup)...\e[0m"
curl -L https://risczero.com/install | bash
export PATH=$PATH:/root/.risc0/bin
echo 'export PATH=$PATH:/root/.risc0/bin' >> /root/.bashrc
source /root/.bashrc
if ! command -v rzup &> /dev/null; then
  echo -e "\e[31mrzup installation failed, please check your network or install manually\e[0m"
  exit 1
fi
echo -e "\e[1;34mInstalling the RISC0 toolchain...\e[0m"
rzup install
rzup_version=$(rzup --version)
echo -e "\e[1;35mCurrent rzup version:\e[0m $rzup_version"

echo -e "\e[1;32mInstalling/upgrading Go to 1.23.1...\e[0m"
wget -q https://go.dev/dl/go1.23.1.linux-amd64.tar.gz -O /tmp/go1.23.1.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go1.23.1.tar.gz
export PATH=/usr/local/go/bin:$PATH
echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc
source /root/.bashrc
go_version=$(go version)
echo -e "\e[1;35mCurrent Go version:\e[0m $go_version"

if ! command -v go &> /dev/null; then
  echo -e "\e[31mGo installation failed, please check your network or install manually\e[0m"
  exit 1
fi
if [[ "$go_version" != *"go1.23"* ]]; then
  echo -e "\e[31mGo version was not upgraded to 1.23.1, please check the installation steps\e[0m"
  exit 1
fi

echo -e "\e[1;34mSetting environment variables...\e[0m"
cat << EOF > $WORK_DIR/.env
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=http://127.0.0.1:8080
PRIVATE_KEY='cli-node-private-key'
EOF
if [ ! -f "$WORK_DIR/.env" ]; then
  echo -e "\e[31mFailed to create .env file, please check permissions or disk space\e[0m"
  exit 1
fi
echo -e "\e[1;35mEnvironment variables have been written to:\e[0m $WORK_DIR/.env"
cat $WORK_DIR/.env

echo -e "\e[1;32mBuilding and starting risc0-merkle-service...\e[0m"
cd $WORK_DIR/risc0-merkle-service
cargo build
if [ $? -ne 0 ]; then
  echo -e "\e[31mrisc0-merkle-service build failed, please check Rust and RISC0 environment\e[0m"
  exit 1
fi
cargo run > risc0.log 2>&1 &
RISC0_PID=$!
echo -e "\e[1;34mrisc0-merkle-service has started, PID: $RISC0_PID, logs output to risc0.log\e[0m"

sleep 5
if ! ps -p $RISC0_PID > /dev/null; then
  echo -e "\e[31mrisc0-merkle-service failed to start, please check $WORK_DIR/risc0-merkle-service/risc0.log\e[0m"
  cat $WORK_DIR/risc0-merkle-service/risc0.log
  exit 1
fi

echo -e "\e[1;32mBuilding and starting light-node...\e[0m"
cd $WORK_DIR
go mod tidy
go build
if [ $? -ne 0 ]; then
  echo -e "\e[31mlight-node build failed, please check Go environment or dependencies\e[0m"
  exit 1
fi

source $WORK_DIR/.env
./light-node > light-node.log 2>&1 &
LIGHT_NODE_PID=$!
echo -e "\e[1;34mlight-node has started, PID: $LIGHT_NODE_PID, logs output to light-node.log\e[0m"

sleep 5
if ! ps -p $LIGHT_NODE_PID > /dev/null; then
  echo -e "\e[31mlight-node failed to start, please check $WORK_DIR/light-node.log\e[0m"
  cat $WORK_DIR/light-node.log
  exit 1
fi

echo -e "\e[1;32mAll services have started!\e[0m"
echo -e "\e[1;34mCheck logs:\e[0m"
echo -e "\e[1;36m- risc0-merkle-service:\e[0m $WORK_DIR/risc0-merkle-service/risc0.log"
echo -e "\e[1;36m- light-node:\e[0m $WORK_DIR/light-node.log"
echo -e "\e[1;33mTo connect to the dashboard, visit dashboard.layeredge.io and use your public key link\e[0m"
