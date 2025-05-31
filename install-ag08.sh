#!/bin/bash

USERNAME=$(whoami)
SCRIPT_PATH="/usr/local/bin/setup-ag08.sh"
RULES_PATH="/etc/udev/rules.d/99-yamaha-ag08.rules"

SERVICE_NAME="ag08-autostart"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
AUTOSTART_SCRIPT="/usr/local/bin/ag08-autostart.sh"

INSTALL_SCRIPT='#!/bin/bash

ACTION=$1
MODULE_FILE="/tmp/ag08_modules.txt"

case "$ACTION" in
    start)
    echo "Yamaha AG08 connected - Sets up sound..."

    if [ -f "$MODULE_FILE" ]; then
      echo "Remap was set up"
      exit 0
    fi

    > "$MODULE_FILE"

    MODULE_ID=$(pactl load-module module-remap-sink sink_name=ag08_34 master=alsa_output.usb-Yamaha_Corporation_Yamaha_AG08-00.analog-surround-71 master_channel_map=front-left,front-right channels=2 channel_map=front-left,front-right sink_properties=device.description="CH3/4 (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-sink sink_name=ag08_56 master=alsa_output.usb-Yamaha_Corporation_Yamaha_AG08-00.analog-surround-71 master_channel_map=front-center,lfe channels=2 channel_map=front-left,front-right sink_properties=device.description="CH5/6 (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-sink sink_name=ag08_78 master=alsa_output.usb-Yamaha_Corporation_Yamaha_AG08-00.analog-surround-71 master_channel_map=rear-left,rear-right channels=2 channel_map=front-left,front-right sink_properties=device.description="CH7/8 (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-sink sink_name=ag08_aux master=alsa_output.usb-Yamaha_Corporation_Yamaha_AG08-00.analog-surround-71 master_channel_map=side-left,side-right channels=2 channel_map=front-left,front-right sink_properties=device.description="AUX (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"

    MODULE_ID=$(pactl load-module module-remap-source source_name=ag08_voice master=alsa_input.usb-Yamaha_Corporation_Yamaha_AG08-00.multichannel-input master_channel_map=aux2,aux3 channels=2 channel_map=front-left,front-right source_properties=device.description="Voice Input (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-source source_name=ag08_streaming master=alsa_input.usb-Yamaha_Corporation_Yamaha_AG08-00.multichannel-input master_channel_map=aux0,aux1 channels=2 channel_map=front-left,front-right source_properties=device.description="Streaming Input (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-source source_name=ag08_aux master=alsa_input.usb-Yamaha_Corporation_Yamaha_AG08-00.multichannel-input master_channel_map=aux4,aux5 channels=2 channel_map=front-left,front-right source_properties=device.description="AUX Input (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    MODULE_ID=$(pactl load-module module-remap-source source_name=ag08_daw master=alsa_input.usb-Yamaha_Corporation_Yamaha_AG08-00.multichannel-input master_channel_map=aux6,aux7,aux8,aux9,aux10,aux11,aux12,aux13 channels=8 channel_map=aux0,aux1,aux2,aux3,aux4,aux5,aux6,aux7 source_properties=device.description="DAW Input (Yamaha AG08 Remap)")
    echo "$MODULE_ID" >> "$MODULE_FILE"
    ;;
    stop)
    echo "Yamaha AG08 disconnected - Cleaning up..."
    if [ -f "$MODULE_FILE" ]; then
      while read -r MODULE_ID; do
        if [ -n "$MODULE_ID" ]; then
          pactl unload-module "$MODULE_ID"
        fi
      done < "$MODULE_FILE"
      rm -f "$MODULE_FILE"
    else
      echo "No module-id file found, nothing to clean up."
    fi
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
'

UDEV_RULE="ACTION==\"add\", SUBSYSTEM==\"sound\", ATTRS{idVendor}==\"0499\", ATTRS{idProduct}==\"175a\", RUN+=\"/usr/bin/su - $USERNAME -c '/usr/local/bin/setup-ag08.sh start'\"
ACTION==\"remove\", SUBSYSTEM==\"sound\", ATTRS{idVendor}==\"0499\", ATTRS{idProduct}==\"175a\", RUN+=\"/usr/bin/su - $USERNAME -c '/usr/local/bin/setup-ag08.sh stop'\""

case "$1" in
  install)
    echo "Install..."
    sudo apt update
    sudo apt install -y pulseaudio-utils
    echo "$INSTALL_SCRIPT" | sudo tee "$SCRIPT_PATH" > /dev/null
    sudo chmod +x "$SCRIPT_PATH"

    echo "$UDEV_RULE" | sudo tee "$RULES_PATH" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    sudo tee "$AUTOSTART_SCRIPT" > /dev/null <<EOF
#!/bin/bash
if lsusb | grep -q "0499:175a"; then
    su - $USERNAME -c "$SCRIPT_PATH start"
fi
EOF

    sudo chmod +x "$AUTOSTART_SCRIPT"

    sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Yamaha AG08 Auto Remap with startup
After=multi-user.target sound.target

[Service]
Type=oneshot
ExecStart=$AUTOSTART_SCRIPT
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME

    echo "Installation complete."

    if lsusb | grep -qi '0499:175a'; then
      bash "$SCRIPT_PATH" start
    fi

    ;;
  uninstall)
    echo "Uninstalling..."
    echo "Running cleanup via setup-ag08.sh stop (if it exists)..."
    bash -c "$SCRIPT_PATH stop" || true
    sudo rm -f "$SCRIPT_PATH"
    sudo rm -f "$RULES_PATH"
    sudo udevadm control --reload-rules

    sudo systemctl disable --now $SERVICE_NAME
    sudo rm -f "$SERVICE_PATH"
    sudo rm -f "$AUTOSTART_SCRIPT"
    sudo systemctl daemon-reload

    echo "Files removed."
    ;;
  *)
    echo "Use: $0 install|uninstall"
    exit 1
    ;;
esac
