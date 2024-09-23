#!/bin/bash


# Ask the user to enter the tunnel name
read -p "Enter the tunnel name you want: " TUNNEL_NAME

# Ask the user to enter the domain
read -p "Enter the domain you want (you must have it in Cloudflare): " DOMAIN

echo ""
echo "Good. Now it is important that you do not have any DNS configured for $DOMAIN"
echo "Go to your Cloudflare DNS panel and if you see any DNS for $DOMAIN, delete it."

read -n 1 -s -r -p "When you have checked it, press any key to continue..."


CREDENTIALS_DIR="/root/.cloudflared"
CONFIG_FILE="/etc/cloudflared/config.yml"

# Verificar y detener cualquier instancia existente de cloudflared
echo "Verificando y deteniendo cualquier instancia existente de cloudflared..."
sudo pkill -f cloudflared

# Desinstalar cualquier servicio cloudflared existente
echo "Desinstalando cualquier servicio cloudflared existente..."
sudo cloudflared service uninstall

# Eliminar archivos de configuración duplicados
echo "Eliminando archivos de configuración duplicados..."
sudo rm -f /etc/cloudflared/config.yml
sudo rm -f /root/.cloudflared/config.yml

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
echo "Instalando dependencias..."
sudo apt install -y ufw

# Agregar la clave de firma de paquete de Cloudflare
echo "Agregando la clave de firma de paquete de Cloudflare..."
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Agregar el repositorio apt de Cloudflare
echo "Agregando el repositorio apt de Cloudflare..."
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Actualizar repositorios e instalar cloudflared
echo "Actualizando repositorios e instalando cloudflared..."
sudo apt-get update && sudo apt-get install -y cloudflared

# Crear usuario cloudflared si no existe
if ! id -u cloudflared > /dev/null 2>&1; then
    echo "Creando usuario cloudflared..."
    sudo useradd -r -s /bin/false cloudflared
fi

# Verificar si el túnel ya existe y eliminarlo si es necesario
EXISTING_TUNNEL_UUID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
if [ -n "$EXISTING_TUNNEL_UUID" ]; then
  echo "Eliminando túnel existente $TUNNEL_NAME con UUID $EXISTING_TUNNEL_UUID..."
  # Cerrar cualquier instancia de cloudflared que esté ejecutando el túnel
  pkill -f "cloudflared tunnel run $TUNNEL_NAME"
  # Limpiar conexiones obsoletas
  cloudflared tunnel cleanup $TUNNEL_NAME
  # Eliminar el túnel
  cloudflared tunnel delete $TUNNEL_NAME
fi

# Autenticar cloudflared (requiere intervención humana)
echo "Por favor, autentica cloudflared. Se abrirá una URL en tu navegador..."
rm ~/.cloudflared/cert.pem
cloudflared tunnel login

# Crear el túnel de Cloudflare
echo "Creando el túnel de Cloudflare..."
cloudflared tunnel create $TUNNEL_NAME

# Obtener el UUID del túnel recién creado
TUNNEL_UUID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')

# Verificar si se obtuvo el UUID
if [ -z "$TUNNEL_UUID" ]; then
  echo "Error: No se pudo obtener el UUID del túnel $TUNNEL_NAME."
  exit 1
fi

# Crear el archivo de configuración de cloudflared en /etc/cloudflared
echo "Creando el archivo de configuración de cloudflared en /etc/cloudflared..."
sudo mkdir -p /etc/cloudflared
sudo bash -c "cat > $CONFIG_FILE <<EOF
tunnel: $TUNNEL_UUID
credentials-file: $CREDENTIALS_DIR/$TUNNEL_UUID.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF"

# Crear el registro DNS (CNAME) para el dominio
echo "Creando el registro DNS (CNAME) para el dominio..."
cloudflared tunnel route dns $TUNNEL_UUID $DOMAIN

# Configurar el firewall (ufw)
echo "Configurando el firewall (ufw)..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable

# Instalar el servicio cloudflared utilizando el archivo de configuración en /etc/cloudflared
echo "Instalando el servicio cloudflared..."
sudo cloudflared --config $CONFIG_FILE service install

# Recargar systemd y habilitar el servicio
echo "Recargando systemd y habilitando el servicio..."
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo "Configuración completada. El túnel de Cloudflare está activo y se ejecuta como un servicio en segundo plano."





# Actualizar los repositorios del sistema
sudo apt update

# Instalar software-properties-common si no está instalado
sudo apt install software-properties-common -y

# Agregar el repositorio de Ondřej Surý para PHP
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Instalar PHP-FPM y extensiones necesarias
sudo apt install php-fpm php-mysql php-xml php-curl php-gd php-mbstring php-zip php-intl php-bcmath php-soap php-redis -y


# Verificar la versión de PHP instalada
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# Verificar la ubicación del socket de PHP-FPM
PHP_FPM_SOCKET="/var/run/php/php${PHP_VERSION}-fpm.sock"
if [ ! -e "$PHP_FPM_SOCKET" ]; then
    echo "Error: PHP-FPM socket not found at $PHP_FPM_SOCKET"
    exit 1
fi



# Eliminar cualquier archivo de configuración de Nginx existente para el dominio
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_CONF_LINK="/etc/nginx/sites-enabled/$DOMAIN"
if [ -e "$NGINX_CONF" ]; then
    sudo rm -f "$NGINX_CONF"
    echo "Eliminado archivo de configuración existente: $NGINX_CONF"
fi
if [ -e "$NGINX_CONF_LINK" ]; then
    sudo rm -f "$NGINX_CONF_LINK"
    echo "Eliminado enlace simbólico existente: $NGINX_CONF_LINK"
fi



# Crear el archivo de configuración de Nginx sin SSL
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
sudo bash -c "cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN/public_html;
    index index.php index.html /index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:$PHP_FPM_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location ~* \.(?:css|js|woff|svg|gif)$ {
        try_files \$uri /index.php;
        expires 6M;
        access_log off;
    }

    location ~* \.(?:png|html|ttf|ico|jpg|jpeg)$ {
        try_files \$uri /index.php;
        expires 30d;
        access_log off;
    }
}
EOF"

# Crear un enlace simbólico en sites-enabled
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

mkdir -p /var/www/$DOMAIN/public_html
echo "<?php echo 'Hello World'; ?>" | sudo tee /var/www/$DOMAIN/public_html/index.php
find /var/www -type d -exec chmod 755 {} \;
sudo find  /var/www -type f -exec chmod 644 {} \;
chown -R www-data:www-data /var/www

# Verificar y recargar la configuración de Nginx
sudo nginx -t && sudo systemctl reload nginx

# Obtener el certificado SSL utilizando Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $DOMAIN

# Actualizar el archivo de configuración de Nginx para usar SSL
sudo bash -c "cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/nextcloud;
    index index.php index.html /index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:$PHP_FPM_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location ~* \.(?:css|js|woff|svg|gif)$ {
        try_files \$uri /index.php;
        expires 6M;
        access_log off;
    }

    location ~* \.(?:png|html|ttf|ico|jpg|jpeg)$ {
        try_files \$uri /index.php;
        expires 30d;
        access_log off;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if (\$host = $DOMAIN) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot

    listen 80;
    server_name $DOMAIN;
    return 404; # managed by Certbot
}
EOF"

# Verificar y recargar la configuración de Nginx
sudo nginx -t && sudo systemctl reload nginx
