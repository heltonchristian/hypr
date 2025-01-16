#sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
#echo "[Service]
#ExecStart=
#ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
