sudo systemctl stop pipe-pop
sudo systemctl disable pipe-pop
sudo rm /etc/systemd/system/pipe-pop.service
sudo systemctl daemon-reload
sleep 1

rm -rf $HOME/pipenetwork

sudo apt update && sudo apt install -y iptables
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker "$USER"
sudo apt-get update && sudo apt install -y libssl-dev ca-certificates jq
sudo apt update && sudo apt install -y iptables-persistent

sudo fuser -k 443/tcp
sleep 5
sudo fuser -k 80/tcp
sleep 5

sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

mkdir pipe_files

INVITE_CODE=$(cat pipe_files/pipe_invite_code.txt)
NODE_NAME=$(cat pipe_files/pipe_node_name.txt)
USERNAME=$(cat pipe_files/pipe_username.txt)
TELEGRAM=$(cat pipe_files/pipe_telegram.txt)
DISCORD=$(cat pipe_files/pipe_discord.txt)
WEBSITE=$(cat pipe_files/pipe_website.txt)
EMAIL=$(cat pipe_files/pipe_email.txt)
SOLANA_PUBKEY=$(cat pipe_files/pipe_solana_pubkey.txt)
RAM_GB=$(cat pipe_files/pipe_ram.txt)
DISK_GB=$(cat pipe_files/pipe_disk.txt)
COUNTRY=$(curl -s http://ip-api.com/json | jq -r '.country')
CITY=$(curl -s http://ip-api.com/json | jq -r '.city')
LOCATION="$CITY, $COUNTRY"
RAM_MB=$(( RAM_GB * 1024 ))

cd..

sudo mkdir -p /opt/popcache && cd /opt/popcache

sudo bash -c 'cat > /etc/sysctl.d/99-popcache.conf << EOL
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL'
sudo sysctl -p /etc/sysctl.d/99-popcache.conf

sudo bash -c 'cat > /etc/security/limits.d/popcache.conf << EOL
*    hard nofile 65535
*    soft nofile 65535
EOL'

wget -q https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz -O pop.tar.gz
tar -xzf pop.tar.gz && rm pop.tar.gz
chmod +x pop
chmod 755 /opt/popcache/pop

cat > config.json <<EOL
{
  "pop_name": "${NODE_NAME}",
  "pop_location": "${LOCATION}",
  "invite_code": "${INVITE_CODE}",
  "server": {"host": "0.0.0.0","port": 443,"http_port": 80,"workers": 0},
  "cache_config": {"memory_cache_size_mb": ${RAM_MB},"disk_cache_path": "./cache","disk_cache_size_gb": ${DISK_GB},"default_ttl_seconds": 86400,"respect_origin_headers": true,"max_cacheable_size_mb": 1024},
  "api_endpoints": {"base_url": "https://dataplane.pipenetwork.com"},
  "identity_config": {"node_name": "${NODE_NAME}","name": "${USERNAME}","email": "${EMAIL}","website": "${WEBSITE}","discord": "${DISCORD}","telegram": "${TELEGRAM}","solana_pubkey": "${SOLANA_PUBKEY}"}
}
EOL

if systemctl list-unit-files --type=service | grep -q '^apache2\.service'; then
  if systemctl is-active --quiet apache2; then
    sudo systemctl stop apache2
  fi

  if systemctl is-enabled --quiet apache2; then
    sudo systemctl disable apache2
  fi
fi

cat > Dockerfile << EOL
FROM ubuntu:24.04

# Install dependensi dasar
RUN apt update && apt install -y \\
    ca-certificates \\
    curl \\
    libssl-dev \\
    && rm -rf /var/lib/apt/lists/*

# Buat direktori untuk pop
WORKDIR /opt/popcache

# Salin file konfigurasi & binary dari host
COPY pop .
COPY config.json .

# Berikan izin eksekusi
RUN chmod +x ./pop

# Jalankan node
CMD ["./pop", "--config", "config.json"]
EOL

docker build -t popnode .
cd ~

docker run -d \
  --name popnode \
  -p 80:80 \
  -p 443:443 \
  --restart unless-stopped \
  popnode
