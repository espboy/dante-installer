#!/bin/bash

# Detener el script si ocurre un error
set -e

echo "Actualizando paquetes y preparando dependencias..."
sudo apt update && sudo apt install -y gcc make libwrap0-dev libpam0g-dev libssl-dev wget tar

echo "Descargando Dante SOCKS5..."
wget http://www.inet.no/dante/files/dante-1.4.2.tar.gz

echo "Extrayendo archivos..."
tar -xvzf dante-1.4.2.tar.gz
cd dante-1.4.2

echo "Compilando e instalando Dante..."
./configure
make && sudo make install

echo "Configurando Dante..."
sudo bash -c 'cat > /etc/danted.conf' <<EOF
logoutput: syslog
internal: 0.0.0.0 port = 1080
external: eth0
method: none
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF

echo "Creando servicio de systemd..."
sudo bash -c 'cat > /etc/systemd/system/danted.service' <<EOF
[Unit]
Description=Dante SOCKS5 Server
After=network.target

[Service]
ExecStart=/usr/local/sbin/sockd -f /etc/danted.conf
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "Habilitando y arrancando el servicio..."
sudo systemctl daemon-reload
sudo systemctl enable danted
sudo systemctl start danted

echo "Configurando el firewall..."
sudo ufw allow 1080/tcp
sudo ufw reload

echo "Dante SOCKS5 instalado y configurado con éxito."

