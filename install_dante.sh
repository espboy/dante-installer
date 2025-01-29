#!/bin/bash

echo "🔄 Actualizando paquetes y preparando dependencias..."

# Eliminar listas corruptas si existen
sudo rm -rf /var/lib/apt/lists/*

# Forzar actualización de paquetes y esperar desbloqueo
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 1; done
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done

# Refrescar listas de paquetes
sudo apt update --fix-missing && sudo apt upgrade -y

# Intentar instalación hasta 3 veces
for i in {1..3}; do
    echo "📦 Intento #$i de instalación de dependencias..."
    sudo apt install -y build-essential gcc make libwrap0-dev libpam0g-dev libssl-dev wget tar && break
    echo "❌ Falló la instalación, reintentando..."
    sleep 5
done

# Verificar que GCC se instaló correctamente
if ! command -v gcc &> /dev/null; then
    echo "🚨 Error: GCC no está instalado. Revisando repositorios..."
    sudo apt install -y gcc
    if ! command -v gcc &> /dev/null; then
        echo "❌ Error crítico: No se pudo instalar GCC. Verifica la conexión de red y repositorios."
        exit 1
    fi
fi

echo "✅ Dependencias instaladas correctamente."

# Descargar Dante
echo "⬇️ Descargando Dante..."
wget http://www.inet.no/dante/files/dante-1.4.2.tar.gz

# Extraer y compilar Dante
echo "📦 Extrayendo Dante..."
tar -xvzf dante-1.4.2.tar.gz
cd dante-1.4.2

echo "⚙️ Configurando Dante..."
./configure
make && sudo make install

# Configuración de Dante
echo "📝 Configurando /etc/danted.conf..."
sudo bash -c 'cat > /etc/danted.conf <<EOF
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
EOF'

# Crear servicio systemd para Dante
echo "🛠️ Creando servicio de systemd para Dante..."
sudo bash -c 'cat > /etc/systemd/system/danted.service <<EOF
[Unit]
Description=Dante SOCKS5 Server
After=network.target

[Service]
ExecStart=/usr/local/sbin/sockd -f /etc/danted.conf
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# Reiniciar y habilitar Dante
echo "🔄 Activando y reiniciando Dante..."
sudo systemctl daemon-reload
sudo systemctl enable danted
sudo systemctl restart danted

# Configurar firewall
echo "🛡️ Configurando firewall..."
sudo ufw allow 1080/tcp
sudo ufw reload

echo "✅ Instalación de Dante completada. Proxy SOCKS5 activo en el puerto 1080."
