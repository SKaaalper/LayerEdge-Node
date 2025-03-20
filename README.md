## One-click run command:
```
curl -L https://raw.githubusercontent.com/SKaaalper/LayerEdge-Node/main/setup_light_node.sh -o setup_light_node.sh && chmod +x setup_light_node.sh && ./setup_light_node.sh
```
➖ Submit your `Private Key` Without `0x`.

## Check Logs:

➖ For Light Node:
```
tail -f /root/light-node/light-node.log
```
➖ Copy your Pubkey Address and submit it to your own dashboard, Now go to ▶️ [Submit Here](https://dashboard.layeredge.io/)  ▶️ Go to **CLI-Based Node Points** if you see `+` then Click ▶️ Submit your `Pubkey Address` And done!

![image](https://github.com/user-attachments/assets/eacdc83c-b0c2-4156-875f-b8b29d06dcb2)

➖ For Light node and Merkle:
```
tail -f /root/light-node/risc0-merkle-service/risc0.log
```

![image](https://github.com/user-attachments/assets/991c7f91-dc16-4175-b371-876a49b249d1)

## Delete Node:
```
pkill light-node && pkill risc0-merkle-service
rm -rf /root/light-node
```

## 🚨 They are currently undergoing maintenance!  You can wait until the maintenance is over before running! 🚨
