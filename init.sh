#!/bin/bash

CONFIG=/boot/config.txt

is_pi () {
	grep -q "^model name\s*:\s*ARMv" /proc/cpuinfo
	return $?
}

get_init_sys() {
  if command -v systemctl > /dev/null && systemctl | grep -q '\-\.mount'; then
    SYSTEMD=1
  elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
    SYSTEMD=0
  else
    echo "Unrecognised init system"
    return 1
  fi
}

if is_pi ; then
  CMDLINE=/boot/cmdline.txt
else
  CMDLINE=/proc/cmdline
fi

#-------------------
# system update
#-------------------
echo ">>> update the list of available packages and their versions."
#sudo apt-get update
	
echo ">>> install newer versions of the packages."
#sudo apt-get upgrade
	
GIT_VERSION=`git --version`
if [ "$GIT_VERSION" = "" ]
	then
		echo ">>> install git."
		sudo apt-get install git-core
		git --version
	else
		echo ">>> install git. (pre-installed)"
		echo $GIT_VERSION
fi
	
#-------------------
# install wiringPi
#-------------------
echo ">>> go to home dir."
cd ~

echo ">>> clone the newest wiringPi."
git clone git://git.drogon.net/wiringPi
cd wiringPi
git pull origin

echo ">>> build&install wiringPi."
./build
	
echo ">>> check the installation of wiringPi."
gpio -v

#-------------------
# disable serial console
# NOTE: In Raspberry Pi 3 Modle B, there is no /etc/inittab file.
#-------------------
echo ">>> enable serial."

get_serial() {
  if grep -q -E "console=(serial0|ttyAMA0|ttyS0)" $CMDLINE ; then
    echo 0
  else
    echo 1
  fi
}

get_serial_hw() {
  if grep -q -E "^enable_uart=1" $CONFIG ; then
    echo 0
  elif grep -q -E "^enable_uart=0" $CONFIG ; then
    echo 1
  elif [ -e /dev/serial0 ] ; then
    echo 0
  else
    echo 1
  fi
}

set_config_var() {
sudo lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

# this flas use to check whether have changed serial serial_service/serial_hardware or not.
DEFAULTS=--defaultno
DEFAULTH=--defaultno
CURRENTS=0
CURRENTH=0
if [ $(get_serial) -eq 0 ]; then
    DEFAULTS=
    CURRENTS=1
fi
if [ $(get_serial_hw) -eq 0 ]; then
    DEFAULTH=
    CURRENTH=1
fi

sudo sed -i $CMDLINE -e "s/console=ttyAMA0,[0-9]\+ //"
sudo sed -i $CMDLINE -e "s/console=serial0,[0-9]\+ //"
sudo cp $CONFIG "$CONFIG.bak"
set_config_var enable_uart 1 $CONFIG
set_config_var dtoverlay pi3-miniuart-bt $CONFIG

#-------------------
# change pi's default secret
#-------------------
echo ">>> change pi's default secret."
#sudo rm -rf /boot/ssh

#-------------------
# add time synchronization logic to cron
#-------------------
echo ">>> create time sync cron job."
sudo apt-get install ntpdate

#-------------------
# change system timezone
#-------------------
echo ">>> change system timezone."
sudo rm -rf /etc/localtime
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

echo ">>> enviroment init complete! do you want to reboot system now? (yes/no) "
read c
if [ $c = "yes" ]; then
	sudo reboot
fi
