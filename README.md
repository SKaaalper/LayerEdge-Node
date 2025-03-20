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
➖ Copy your Pubkey Address and submit it to your own dashboard, Now go to ▶️ [Submit Here](https://dashboard.layeredge.io/)  ▶️ Go to **CLI-Based Node Points** if you see **+** then Click ▶️ Submit your `Pubkey Address` And done!

![image](https://github.com/user-attachments/assets/eacdc83c-b0c2-4156-875f-b8b29d06dcb2)

➖ For Light node and Merkle:
```
tail -f /root/light-node/risc0-merkle-service/risc0.log
```

## Delete Node:
```
pkill light-node && pkill risc0-merkle-service
rm -rf /root/light-node
```

![image](https://github.com/user-attachments/assets/5efe647b-9a08-48e1-98f4-b81f22f415e1)


## 🚨 They are currently undergoing maintenance!  You can wait until the maintenance is over before running! 🚨
