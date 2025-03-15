#!/bin/bash

echo "Starting aggressive TAK Server removal..."

# Stop all TAK-related services
echo "Stopping all TAK-related services..."
services=(
    "takserver"
    "takserver-plugins"
    "takserver-messaging"
    "takserver-api"
    "takserver-config"
    "takserver-noplugins"
    "takserver-retention"
    "postgresql"
)

for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "Stopping $service..."
        systemctl stop $service
        systemctl disable $service
    fi
done

# Kill all TAK-related processes
echo "Killing all TAK-related processes..."
pkill -f takserver
sleep 2

# Backup PostgreSQL data if needed
echo "Do you want to backup the TAK database before removing? (y/n)"
read -r backup_choice
if [[ $backup_choice =~ ^[Yy]$ ]]; then
    echo "Creating database backup..."
    if command -v sudo -u postgres >/dev/null 2>&1; then
        sudo -u postgres pg_dump tak > tak_backup_$(date +%Y%m%d).sql
        echo "Database backup created: tak_backup_$(date +%Y%m%d).sql"
    else
        echo "WARNING: Could not create database backup. Proceeding with removal..."
    fi
fi

# Remove PostgreSQL database and user
echo "Removing PostgreSQL database and user..."
if command -v sudo -u postgres >/dev/null 2>&1; then
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS tak;"
    sudo -u postgres psql -c "DROP USER IF EXISTS tak;"
fi

# Remove PostgreSQL installation (optional)
echo "Do you want to remove PostgreSQL completely? (y/n)"
read -r remove_postgres
if [[ $remove_postgres =~ ^[Yy]$ ]]; then
    echo "Removing PostgreSQL..."
    apt-get purge -y postgresql*
    rm -rf /var/lib/postgresql/
    rm -rf /var/log/postgresql/
    rm -rf /etc/postgresql/
fi

# Remove init.d scripts
echo "Removing init.d scripts..."
rm -f /etc/init.d/takserver*

# Remove all TAK service files
echo "Removing TAK service files..."
rm -f /etc/systemd/system/takserver*.service
rm -f /usr/lib/systemd/system/takserver*.service
rm -f /lib/systemd/system/takserver*.service

# Reload systemd and reset failed units
echo "Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed

# Remove the problematic post-removal script
echo "Removing problematic package scripts..."
if [ -f /var/lib/dpkg/info/takserver.postrm ]; then
    mv /var/lib/dpkg/info/takserver.postrm /var/lib/dpkg/info/takserver.postrm.bad
fi

# Force remove directories and files
echo "Removing TAK directories and files..."
rm -rf /opt/tak
rm -rf /usr/share/debsig
rm -rf /etc/debsig
rm -rf /var/lib/dpkg/info/takserver*

# Force package removal
echo "Force removing TAK Server package..."
dpkg --remove --force-remove-reinstreq takserver
dpkg --purge --force-all takserver

# Clean up package manager state
echo "Cleaning up package manager state..."
apt-get clean
apt-get autoremove -y
dpkg --configure -a
apt-get -f install -y

# Remove JVM limits configuration
echo "Removing JVM limits configuration..."
sed -i '/# Applying JVM Limits/d' /etc/security/limits.conf
sed -i '/*      soft      nofile      32768/d' /etc/security/limits.conf
sed -i '/*      hard      nofile      32768/d' /etc/security/limits.conf

# Remove firewall rules
echo "Removing firewall rules..."
if command -v ufw >/dev/null 2>&1; then
    ufw delete allow 8089
    ufw delete allow 8443
    ufw delete allow 8446
    ufw delete allow 9000
    ufw delete allow 9001
    ufw delete allow 8090/udp
fi

# Remove enrollment datapackage and certificates
echo "Removing enrollment datapackage and certificates..."
rm -f $HOME/enrollmentDP.zip
rm -f $HOME/enrollmentDP-QUIC.zip
rm -f $HOME/caCert.p12
rm -f $HOME/webadmin.p12
rm -f $HOME/takdatapackagedesc

# Remove Let's Encrypt certificates and configuration if they exist
if [ -d "/etc/letsencrypt" ]; then
    echo "Removing Let's Encrypt certificates..."
    rm -f /etc/cron.d/certbot-tak-le
    rm -f /opt/tak/renew-tak-le
fi

# Remove log file
echo "Removing installation log..."
rm -f /tmp/.takinstall.log

# Force systemd to forget about these units
echo "Forcing systemd to forget about TAK units..."
for service in "${services[@]}"; do
    systemctl stop $service 2>/dev/null
    systemctl disable $service 2>/dev/null
    rm -f /etc/systemd/system/$service.service
    rm -f /usr/lib/systemd/system/$service.service
    rm -f /lib/systemd/system/$service.service
    systemctl reset-failed $service 2>/dev/null
done

# Reload systemd one final time
systemctl daemon-reload

# Final verification
echo "Performing final verification..."
if systemctl list-unit-files | grep -q "takserver"; then
    echo "WARNING: Some TAK services are still present. You may need to reboot the system."
    echo "After reboot, verify with: systemctl list-unit-files | grep tak"
else
    echo "All TAK services removed successfully."
fi

if dpkg -l | grep -q "^ii.*takserver"; then
    echo "WARNING: TAK Server package still shows as installed. Manual intervention may be required."
    echo "You can try: dpkg --get-selections | grep tak"
    echo "And then: dpkg --purge takserver"
else
    echo "TAK Server package removed successfully."
fi

# Verify PostgreSQL cleanup
if [[ $remove_postgres =~ ^[Yy]$ ]]; then
    if dpkg -l | grep -q "^ii.*postgresql"; then
        echo "WARNING: PostgreSQL might still be installed. You may need to remove it manually."
    else
        echo "PostgreSQL removed successfully."
    fi
fi

echo "Uninstallation complete. A system reboot is recommended."
