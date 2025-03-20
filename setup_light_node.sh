#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as the root user"
  exit 1
fi

clear
echo -e "\n=========================================="
echo -e "=           LayerEdge Node           ="
echo -e "=  https://t.me/KatayanAirdropGnC    ="
echo -e "=           Batang Eds               ="
echo -e "==========================================\n"

WORK_DIR="/root/light-node"
echo "Working directory: $WORK_DIR"

echo "Installing basic tools (git, curl, netcat)..."
apt update
apt install -y git curl netcat-openbsd

if [ -d "$WORK_DIR" ]; then
  echo "Detected that $WORK_DIR already exists, attempting to update..."
  cd $WORK_DIR
  git pull
else
  echo "Cloning the Layer Edge Light Node repository..."
  git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR
  cd $WORK_DIR
fi
if [ $? -ne 0 ]; then
  echo "Failed to clone or update the repository, please check your network or permissions"
  exit 1
fi

if ! command -v rustc &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi
rust_version=$(rustc --version)
echo "Current Rust version: $rust_version"

echo "Installing the RISC0 toolchain manager (rzup)..."
curl -L https://risczero.com/install | bash
export PATH=$PATH:/root/.risc0/bin
echo 'export PATH=$PATH:/root/.risc0/bin' >> /root/.bashrc
source /root/.bashrc
if ! command -v rzup &> /dev/null; then
  echo "rzup installation failed, please check your network or install manually"
  exit 1
fi
echo "Installing the RISC0 toolchain..."
rzup install
rzup_version=$(rzup --version)
echo "Current rzup version: $rzup_version"

echo "Installing/upgrading Go to 1.23.1..."
wget -q https://go.dev/dl/go1.23.1.linux-amd64.tar.gz -O /tmp/go1.23.1.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go1.23.1.tar.gz
export PATH=/usr/local/go/bin:$PATH
echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc
source /root/.bashrc
go_version=$(go version)
echo "Current Go version: $go_version"

if ! command -v go &> /dev/null; then
  echo "Go installation failed, please check your network or install manually"
  exit 1
fi
if [[ "$go_version" != *"go1.23"* ]]; then
  echo "Go version was not upgraded to 1.23.1, please check the installation steps"
  exit 1
fi

echo "Setting environment variables..."
cat << EOF > $WORK_DIR/.env
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=http://127.0.0.1:8080
PRIVATE_KEY='cli-node-private-key'
EOF
if [ ! -f "$WORK_DIR/.env" ]; then
  echo "Failed to create .env file, please check permissions or disk space"
  exit 1
fi
echo "Environment variables have been written to $WORK_DIR/.env"
cat $WORK_DIR/.env

echo "Building and starting risc0-merkle-service..."
cd $WORK_DIR/risc0-merkle-service
cargo build
if [ $? -ne 0 ]; then
  echo "risc0-merkle-service build failed, please check Rust and RISC0 environment"
  exit 1
fi
cargo run > risc0.log 2>&1 &
RISC0_PID=$!
echo "risc0-merkle-service has started, PID: $RISC0_PID, logs output to risc0.log"

sleep 5
if ! ps -p $RISC0_PID > /dev/null; then
  echo "risc0-merkle-service failed to start, please check $WORK_DIR/risc0-merkle-service/risc0.log"
  cat $WORK_DIR/risc0-merkle-service/risc0.log
  exit 1
fi

echo "Building and starting light-node..."
cd $WORK_DIR
go mod tidy
go build
if [ $? -ne 0 ]; then
  echo "light-node build failed, please check Go environment or dependencies"
  exit 1
fi

source $WORK_DIR/.env
./light-node > light-node.log 2>&1 &
LIGHT_NODE_PID=$!
echo "light-node has started, PID: $LIGHT_NODE_PID, logs output to light-node.log"

sleep 5
if ! ps -p $LIGHT_NODE_PID > /dev/null; then
  echo "light-node failed to start, please check $WORK_DIR/light-node.log"
  cat $WORK_DIR/light-node.log
  exit 1
fi

echo "All services have started, Congrats 🎉!"
echo "Check logs:"
echo "- risc0-merkle-service: $WORK_DIR/risc0-merkle-service/risc0.log"
echo "- light-node: $WORK_DIR/light-node.log"
echo "To connect to the dashboard, visit dashboard.layeredge.io and use your public key link"

