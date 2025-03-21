#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run this script as the root user\e[0m"
  exit 1
fi

clear
echo -e "\e[1;34m==========================================\e[0m"
echo -e "\e[1;32m=          Layer Edge Node Setup      =\e[0m"
echo -e "\e[1;36m=  https://t.me/KatayanAirdropGnC    =\e[0m"
echo -e "\e[1;33m=           Batang Eds               =\e[0m"
echo -e "\e[1;34m==========================================\e[0m\n"

WORK_DIR="/root/light-node"
echo -e "\e[1;35mWorking directory:\e[0m $WORK_DIR"

sudo ufw allow 9090
sudo ufw allow 3001

apt update
apt install -y git curl netcat-openbsd build-essential

if [ -d "$WORK_DIR" ]; then
  echo -e "\e[1;33mDetected that $WORK_DIR already exists, updating...\e[0m"
  cd $WORK_DIR && git pull
else
  echo -e "\e[1;32mCloning Layer Edge Light Node repository...\e[0m"
  git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR && cd $WORK_DIR
fi

if ! command -v rustc &> /dev/null; then
  echo -e "\e[1;32mInstalling Rust...\e[0m"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi

echo -e "\e[1;32mInstalling the RISC0 toolchain manager (rzup)...\e[0m"
curl -L https://risczero.com/install | bash
export PATH=$PATH:/root/.risc0/bin
echo 'export PATH=$PATH:/root/.risc0/bin' >> /root/.bashrc
source /root/.bashrc
rzup install

echo -e "\e[1;32mInstalling/upgrading Go to 1.23.1...\e[0m"
wget -q https://go.dev/dl/go1.23.1.linux-amd64.tar.gz -O /tmp/go1.23.1.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go1.23.1.tar.gz
export PATH=/usr/local/go/bin:$PATH
echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc
source /root/.bashrc

echo -e "\e[1;32mEnter your MetaMask Private Key (64-character hexadecimal string):\e[0m"
read -r PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ] || [ ${#PRIVATE_KEY} -ne 64 ]; then
  echo -e "\e[31mInvalid private key. It must be a 64-character hexadecimal string.\e[0m"
  exit 1
fi

echo -e "\e[1;32mEnter your GRPC_URL (default is grpc.testnet.layeredge.io:9090, press Enter to use default):\e[0m"
read -r GRPC_URL
if [ -z "$GRPC_URL" ]; then
  GRPC_URL="grpc.testnet.layeredge.io:9090"
fi

echo -e "\e[1;32mChoose ZK_PROVER_URL (Enter 1 for local http://127.0.0.1:3001, Enter 2 for https://layeredge.mintair.xyz/, default is 1):\e[0m"
read -r ZK_CHOICE
if [ "$ZK_CHOICE" = "2" ]; then
  ZK_PROVER_URL="https://layeredge.mintair.xyz/"
else
  ZK_PROVER_URL="http://127.0.0.1:3001"
fi

echo -e "\e[1;34mSetting environment variables...\e[0m"
cat << EOF > $WORK_DIR/.env
GRPC_URL=$GRPC_URL
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=$ZK_PROVER_URL
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$PRIVATE_KEY'
EOF

echo -e "\e[1;32mBuilding and starting risc0-merkle-service...\e[0m"
cd $WORK_DIR/risc0-merkle-service
cargo build --release
cargo run --release > risc0.log 2>&1 &

echo -e "\e[1;32mBuilding and starting light-node...\e[0m"
cd $WORK_DIR
go mod tidy
go build -o light-node main.go
source $WORK_DIR/.env
nohup ./light-node > light-node.log 2>&1 &

echo -e "\e[1;32mAll services have started!\e[0m"
echo -e "\e[1;34mCheck logs:\e[0m"
echo -e "\e[1;36m- risc0-merkle-service:\e[0m $WORK_DIR/risc0-merkle-service/risc0.log"
echo -e "\e[1;36m- light-node:\e[0m $WORK_DIR/light-node.log"
echo -e "\e[1;33mTo connect to the dashboard, visit dashboard.layeredge.io and use your public key link\e[0m"

