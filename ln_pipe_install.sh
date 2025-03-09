if ! command -v curl &> /dev/null; then
    sudo apt update -y
    sudo apt install curl -y
f

WALLET=$(cd $HOME/pipenetwork && cat wallet_address.txt)
RAM=$(cd $HOME/pipenetwork && cat ram_amount.txt)
DISK=$(cd $HOME/pipenetwork && cat disk_amount.txt)

mkdir -p $HOME/pipenetwork
mkdir -p $HOME/pipenetwork/download_cache

curl -o $HOME/pipenetwork/pop https://dl.pipecdn.app/v0.2.8/pop
chmod +x $HOME/pipenetwork/pop
$HOME/pipenetwork/pop --refresh

echo -e "ram=$RAM\nmax-disk=$DISK\ncache-dir=$HOME/pipenetwork/download_cache\npubKey=$WALLET" > pipenetwork/.env
cd $HOME/pipenetwork && sudo ./pop --signup-by-referral-route 915b43ddffb7a015

sudo tee /etc/systemd/system/pipe-pop.service > /dev/null << EOF
[Unit]
Description=Pipe POP Node Service
After=network.target
Wants=network-online.target

[Service]
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$HOME/pipenetwork
ExecStart=$HOME/pipenetwork/pop \
    --ram $RAM \
    --max-disk $DISK \
    --cache-dir $HOME/pipenetwork/download_cache \
    --pubKey $WALLET
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sleep 1
sudo systemctl enable pipe-pop
sudo systemctl start pipe-pop
