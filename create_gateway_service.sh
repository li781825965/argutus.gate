echo ">>> create gateway service."
sudo wget https://raw.githubusercontent.com/li781825965/argutus.gate/master/gateway.service -P /lib/systemd/system
sudo chmod 644 /lib/systemd/system/gateway.service
sudo systemctl daemon-reload
sudo systemctl enable gateway.service
sudo systemctl start gateway.service
sudo systemctl status gateway.service