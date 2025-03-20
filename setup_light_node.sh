#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

WORK_DIR="/root/light-node"
echo "Working directory: $WORK_DIR"

echo "Installing basic tools (git, curl, netcat)..."
apt update
apt install -y git curl netcat-openbsd

if [ -d "$WORK_DIR" ]; then
  echo "$WORK_DIR detected, updating..."
  cd $WORK_DIR
  git pull
else
  echo "Cloning Layer Edge Light Node repository..."
  git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR
  cd $WORK_DIR
fi
if [ $? -ne 0 ]; then
  echo "Failed to clone or update repository"
  exit 1
fi

if ! command -v rustc &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi
rust_version=$(rustc --version)
echo "Rust version: $rust_version"

echo "Installing RISC0 toolchain..."
curl -L https://risczero.com/install | bash
export PATH=$PATH:/root/.risc0/bin
echo 'export PATH=$PATH:/root/.risc0/bin' >> /root/.bashrc
source /root/.bashrc
if ! command -v rzup &> /dev/null; then
  echo "rzup installation failed"
  exit 1
fi
rzup install
rzup_version=$(rzup --version)
echo "rzup version: $rzup_version"

echo "Installing Go 1.23.1..."
wget -q https://go.dev/dl/go1.23.1.linux-amd64.tar.gz -O /tmp/go1.23.1.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go1.23.1.tar.gz
export PATH=/usr/local/go/bin:$PATH
echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc
source /root/.bashrc
go_version=$(go version)
echo "Go version: $go_version"

if ! command -v go &> /dev/null; then
  echo "Go installation failed"
  exit 1
fi
if [[ "$go_version" != *"go1.23"* ]]; then
  echo "Go version is not 1.23.1, please check installation"
  exit 1
fi

echo "Enter your PRIVATE_KEY (64-character hex string):"
read -r PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ] || [ ${#PRIVATE_KEY} -ne 64 ]; then
  echo "Invalid private key, please rerun the script"
  exit 1
fi

echo "Enter your GRPC_URL (default 34.31.74.109:9090):"
read -r GRPC_URL
GRPC_URL=${GRPC_URL:-34.31.74.109:9090}

echo "Choose ZK_PROVER_URL (1 for local, 2 for cloud):"
read -r ZK_CHOICE
if [ "$ZK_CHOICE" = "2" ]; then
  ZK_PROVER_URL="https://layeredge.mintair.xyz/"
else
  ZK_PROVER_URL="http://127.0.0.1:3001"
fi

echo "Testing GRPC_URL connectivity: $GRPC_URL..."
GRPC_HOST=$(echo $GRPC_URL | cut -d: -f1)
GRPC_PORT=$(echo $GRPC_URL | cut -d: -f2)
nc -zv $GRPC_HOST $GRPC_PORT
if [ $? -ne 0 ]; then
  echo "Warning: Cannot connect to $GRPC_URL"
fi

echo "Creating .env file..."
cat << EOF > $WORK_DIR/.env
GRPC_URL=$GRPC_URL
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=$ZK_PROVER_URL
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$PRIVATE_KEY'
EOF
chmod 600 $WORK_DIR/.env

echo "Building risc0-merkle-service..."
cd $WORK_DIR/risc0-merkle-service
cargo build
if [ $? -ne 0 ]; then
  echo "Failed to build risc0-merkle-service"
  exit 1
fi
cargo run > risc0.log 2>&1 &
echo "risc0-merkle-service running, log at risc0.log"

sleep 5
echo "Building light-node..."
cd $WORK_DIR
go mod tidy
go build
if [ $? -ne 0 ]; then
  echo "Failed to build light-node"
  exit 1
fi

source $WORK_DIR/.env
./light-node > light-node.log 2>&1 &
echo "light-node running, log at light-node.log"

sleep 5
echo "Setup complete!"
