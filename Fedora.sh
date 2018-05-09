#!/bin/bash
#
#<UDF name="ssuser" Label="Sudo user username?" example="username" />
#<UDF name="sspassword" Label="Sudo user password?" example="strongPassword" />
#<UDF name="sspubkey" Label="SSH pubkey (installed for root and sudo user)?" example="ssh-rsa ..." />
#<UDF name="sshostname" Label="Fully qualified domain name?" example="example.jansen.sh" />
#
# Works for Fedora 27

if [[ ! $SSUSER ]]; then read -p "Sudo user username?" SSUSER; fi
if [[ ! $SSPASSWORD ]]; then read -p "Sudo user password?" SSPASSWORD; fi
if [[ ! $SSPUBKEY ]]; then read -p "SSH pubkey (installed for root and sudo user)?" SSPUBKEY; fi
if [[ ! $SSHOSTNAME ]]; then read -p "Fully qualified domain name?" SSHOSTNAME; fi

# setting fully-qualified domain name
hostnamectl set-hostname $SSHOSTNAME

# set up sudo user
echo Setting sudo user: $SSUSER...
useradd $SSUSER && echo $SSPASSWORD | passwd $SSUSER --stdin
usermod -aG wheel $SSUSER
echo ...done
# sudo user complete

# set up ssh pubkey
# for x in... loop doesn't work here, sadly
echo Setting up ssh pubkeys...
mkdir -p /root/.ssh
mkdir -p /home/$SSUSER/.ssh
echo "$SSPUBKEY" > /root/.ssh/authorized_keys
echo "$SSPUBKEY" > /home/$SSUSER/.ssh/authorized_keys
chmod -R 700 /root/.ssh
chmod -R 700 /home/${SSUSER}/.ssh
chown -R ${SSUSER}:${SSUSER} /home/${SSUSER}/.ssh
echo ...done

# disable password and root over ssh
echo Disabling passwords and root login over ssh...
sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
echo Restarting sshd...
systemctl restart sshd
echo ...done

#remove unneeded services
echo Removing unneeded services...
dnf remove -y avahi chrony
echo ...done

# Needful time
dnf update -y

### dnf automatic updates
echo Setting up automatic updates...
dnf install -y dnf-automatic
sed -i -e "s/apply_updates = no/apply_updates = yes/" /etc/dnf/automatic.conf
systemctl enable dnf-automatic.timer
systemctl start dnf-automatic.timer
echo ...done
# automatic updates complete

# set up fail2ban
echo Setting up fail2ban...
dnf install -y fail2ban
cd /etc/fail2ban
cp fail2ban.conf fail2ban.local
cp jail.conf jail.local
sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban
echo ...done

# set up firewalld
echo Setting up firewalld...
systemctl start firewalld
systemctl enable firewalld
# Use public zone
firewall-cmd --set-default-zone=public
firewall-cmd --zone=public --add-interface=eth0
firewall-cmd --reload
echo ...done

# Set up distro kernel and grub
dnf install -y kernel grub2
sed -i -e "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=10/" /etc/default/grub
sed -i -e "s/crashkernel=auto rhgb console=ttyS0,19200n8/console=ttyS0,19200n8/" /etc/default/grub
mkdir /boot/grub
grub2-mkconfig -o /boot/grub/grub.cfg

# ensure ntp is installed and running
dnf install -y ntp
systemctl enable ntp
systemctl start ntp

# Done!
echo All finished! Rebooting...
(sleep 5; reboot) &
