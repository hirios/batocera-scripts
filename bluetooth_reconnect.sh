#!/bin/bash

RETRY_INTERVAL=7

# Função para reiniciar o serviço Bluetooth no Batocera
function restart_bluetooth_service() {
  echo "$(date): Reiniciando Bluetooth via batocera-bluetooth..."
  /usr/bin/batocera-bluetooth disable
  sleep 2
  /usr/bin/batocera-bluetooth enable
  sleep 5
}

# Pega o endereço do adaptador Bluetooth ativo
ADAPTER=$(hciconfig | awk '
  BEGIN {bd_address=""}
  /^hci[0-9]+:/ {adapter=$1; bd_address=""}
  /BD Address:/ {bd_address=$3}
  /UP RUNNING/ {print bd_address; exit}
')

if [ -z "$ADAPTER" ]; then
  echo "Nenhum adaptador Bluetooth ativo encontrado."
  exit 1
fi

echo "Adaptador Bluetooth ativo: $ADAPTER"

while true; do
  # Lista dispositivos pareados (pastas dentro do adaptador)
  PAIRED_DEVICES=$(ls -d /var/lib/bluetooth/"$ADAPTER"/[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F] 2>/dev/null | xargs -n1 basename)

  if [ -z "$PAIRED_DEVICES" ]; then
    echo "Nenhum dispositivo pareado encontrado."
  fi

  echo "Ligando scan..."
  timeout 5 bluetoothctl scan on
  if [ $? -ne 0 ]; then
    echo "$(date): Timeout ou falha ao ligar scan"
    restart_bluetooth_service
    continue
  fi

  sleep 5

  bluetoothctl scan off || echo "Falha ao parar scan, pode ser ignorado."

  # Lista dispositivos visíveis no momento
  VISIBLE_DEVICES=$(bluetoothctl devices | awk '{print $2}')

  for MAC in $PAIRED_DEVICES; do
    if echo "$VISIBLE_DEVICES" | grep -Fxq "$MAC"; then
      echo "$(date): Tentando reconectar $MAC ..."
      bluetoothctl connect "$MAC"
    else
      echo "$(date): Dispositivo $MAC não está visível, pulando."
    fi
  done

  echo "Aguardando $RETRY_INTERVAL segundos para próxima tentativa..."
  sleep $RETRY_INTERVAL
done
