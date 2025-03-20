## One-click run command:
```
curl -L https://raw.githubusercontent.com/SKaaalper/LayerEdge-Node/main/setup_light_node.sh -o setup_light_node.sh && chmod +x setup_light_node.sh && ./setup_light_node.sh
```

## Check Logs:

➖ For Light Node:
```
tail -f /root/light-node/light-node.log
```
➖ For Light node and Merkle:
```
tail -f /root/light-node/risc0-merkle-service/risc0.log
```

## Delete Node:
```
pkill light-node && pkill risc0-merkle-service
rm -rf /root/light-node
```
## 🚨 They are currently undergoing maintenance!  You can wait until the maintenance is over before running! 🚨
