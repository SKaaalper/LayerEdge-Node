#!/bin/bash

clear
echo -e "\e[1;34m==========================================\e[0m"
echo -e "\e[1;32m=          Layer Edge Node Setup      =\e[0m"
echo -e "\e[1;36m=  https://t.me/KatayanAirdropGnC    =\e[0m"
echo -e "\e[1;33m=           Batang Eds               =\e[0m"
echo -e "\e[1;34m==========================================\e[0m\n"

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

WORK_DIR="/root/light-node"
echo "Working Directory: $WORK_DIR"

echo "Installing essential tools (git, curl, netcat, and others)..."
sudo apt update
sudo apt install -y git curl netcat-openbsd
sudo apt install -y build-essential pkg-config libssl-dev protobuf-compiler screen

if [ -d "$WORK_DIR" ]; then
  echo "Detected that $WORK_DIR exists, attempting to update..."
  cd $WORK_DIR
  git pull
else
  echo "Cloning Layer Edge Light Node repository..."
  git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR
  cd $WORK_DIR
fi
if [ $? -ne 0 ]; then
  echo "Failed to clone or update repository, check network or permissions"
  exit 1
fi

if ! command -v rustc &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi
rust_version=$(rustc --version)
echo "Current Rust version: $rust_version"

echo "Installing RISC0 toolchain manager (rzup)..."
curl -L https://risczero.com/install | bash
export PATH=$PATH:/root/.risc0/bin
echo 'export PATH=$PATH:/root/.risc0/bin' >> /root/.bashrc
source /root/.bashrc
if ! command -v rzup &> /dev/null; then
  echo "rzup installation failed, check network or install manually"
  exit 1
fi
echo "Installing RISC0 toolchain..."
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
  echo "Go installation failed, check network or install manually"
  exit 1
fi
if [[ "$go_version" != *"go1.23"* ]]; then
  echo "Go version not upgraded to 1.23.1, check installation steps"
  exit 1
fi

# User inputs for .env file
echo "Please enter your PRIVATE_KEY (64-character hexadecimal string, press Enter after input):"
read -r PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ] || [ ${#PRIVATE_KEY} -ne 64 ]; then
  echo "Invalid private key, it must be a 64-character hexadecimal string. Please rerun the script"
  exit 1
fi

echo "Please enter your GRPC_URL (default is grpc.testnet.layeredge.io:9090, press Enter to use the default):"
read -r GRPC_URL
if [ -z "$GRPC_URL" ]; then
  GRPC_URL="grpc.testnet.layeredge.io:9090"
fi

echo "Choose ZK_PROVER_URL (Enter 1 for local http://127.0.0.1:3001, Enter 2 for https://layeredge.mintair.xyz/, default is 1):"
read -r ZK_CHOICE
if [ "$ZK_CHOICE" = "2" ]; then
  ZK_PROVER_URL="https://layeredge.mintair.xyz/"
else
  ZK_PROVER_URL="http://127.0.0.1:3001"
fi

echo "Testing GRPC_URL reachability: $GRPC_URL..."
GRPC_HOST=$(echo $GRPC_URL | cut -d: -f1)
GRPC_PORT=$(echo $GRPC_URL | cut -d: -f2)
nc -zv $GRPC_HOST $GRPC_PORT
if [ $? -ne 0 ]; then
  echo "Warning: Unable to connect to $GRPC_URL, check address or try again later"
fi

echo "Setting environment variables..."
cat << EOF > $WORK_DIR/.env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='cli-node-private-key'
EOF
if [ ! -f "$WORK_DIR/.env" ]; then
  echo "Failed to create .env file, check permissions or disk space"
  exit 1
fi
echo "Environment variables written to $WORK_DIR/.env"
cat $WORK_DIR/.env

echo "Building and starting risc0-merkle-service..."
cd $WORK_DIR/risc0-merkle-service
cargo build
if [ $? -ne 0 ]; then
  echo "risc0-merkle-service build failed, check Rust and RISC0 environment"
  exit 1
fi
cargo run > risc0.log 2>&1 & 
RISC0_PID=$!
echo "risc0-merkle-service started, PID: $RISC0_PID, logs in risc0.log"

sleep 5
if ! ps -p $RISC0_PID > /dev/null; then
  echo "risc0-merkle-service failed to start, check $WORK_DIR/risc0-merkle-service/risc0.log"
  cat $WORK_DIR/risc0-merkle-service/risc0.log
  exit 1
fi

echo "Building and starting light-node..."
cd $WORK_DIR
go mod tidy
go build
if [ $? -ne 0 ]; then
  echo "light-node build failed, check Go environment or dependencies"
  exit 1
fi

source $WORK_DIR/.env
./light-node > light-node.log 2>&1 &
LIGHT_NODE_PID=$!
echo "light-node started, PID: $LIGHT_NODE_PID, logs in light-node.log"

sleep 5
if ! ps -p $LIGHT_NODE_PID > /dev/null; then
  echo "light-node failed to start, check $WORK_DIR/light-node.log"
  cat $WORK_DIR/light-node.log
  exit 1
fi

echo "All services started!"
echo "Check logs:"
echo "- risc0-merkle-service: $WORK_DIR/risc0-merkle-service/risc0.log"
echo "- light-node: $WORK_DIR/light-node.log"
echo "To connect to the dashboard, visit dashboard.layeredge.io and use your public key"
