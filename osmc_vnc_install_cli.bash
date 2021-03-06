#!/bin/bash
# Set UTF-8; e.g. "en_US.UTF-8" or "de_DE.UTF-8":
#export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

# Tell ncurses to use line characters that work with UTF-8.
export NCURSES_NO_UTF8_ACS=1

separator=":"

function CHECK_ROOT {
  # check if root for future installations
  if [ "$(id -u)" != "0" ];
    then
      HELP
      exit 1
  fi
}

function CHECK_SERVICE_ACTIVE {
  if [ "`systemctl show dispmanx_vncserver.service -p ActiveState`" = "ActiveState=active" ]
    then
      systemctl stop dispmanx_vncserver.service
  fi
}

function CHECK_SERVICE_INACTIVE {
  if [ "`systemctl show dispmanx_vncserver.service -p ActiveState`" = "ActiveState=inactive" ]
    then
      systemctl start dispmanx_vncserver.service
  fi
}

function CHECK_SERVICE_ENABLED {
  if [ "`systemctl is-enabled dispmanx_vncserver.service`" = "enabled" ]
    then
      systemctl disable dispmanx_vncserver.service
  fi
}

function CHECK_SERVICE_DISABLED {
  if [ "`systemctl is-enabled dispmanx_vncserver.service`" = "disabled" ]
    then
      systemctl enable dispmanx_vncserver.service
  fi
}

function OPTIONS {
  case $VALUE in
    1) OSMC_UPATE;;
    2) INSTALL_VNC_SERVER_AND_SERVICE
       CHANGE_VNC_SETTINGS --nocancel;;
    3) REMOVE_VNC_SERVER_AND_SERVICE
       DONE
       MENU;;
    4) UPDATE_VNC_SERVER
       DONE
       MENU;;
    5) CHANGE_VNC_SETTINGS;;
    6) START_VNC;;
    7) STOP_VNC;;
    8) ACTIVATE_VNC_SERVICE;;
    9) DEACTIVATE_VNC_SERVICE;;
  esac
}

function APT_UPDATE {
  apt-get update 1> /dev/null
  apt-get -y dist-upgrade 1> /dev/null
}

function APT_CLEAN {
  apt-get -y autoclean
  apt-get -y autoremove
}

function OSMC_UPATE {
  echo "Iniciando"
  APT_UPDATE
  APT_CLEAN
  if [ -n "$1" ];
    then
      REBOOT_FOLLOWS
  fi
  sleep 0.5
  clear
  reboot
}

function REBOOT_FOLLOWS {
  dialog --backtitle "Instalando VNC-Server em OSMC" \
         --infobox "Reiniciar" \
         5 20
}

function DONE {
  dialog --backtitle "Instalando VNC-Server em OSMC" \
         --infobox "Instalado com sucesso" \
         5 20
  sleep 0.5
}

function EXIT {
  dialog --backtitle "Instalando VNC-Server em OSMC" \
         --infobox "Sair" \
         5 20
  sleep 0.5
  clear
}

function INSTALL_VNC_SERVER_AND_SERVICE {
  echo -n "Iniciando"
  APT_UPDATE
  APT_INSTALL
  CREATE_VNC_SERVER
  COPY_CONF
  CLEANUP_INSTALL
  CREATE_SERVICE_FILE
  systemctl daemon-reload
  ACTIVATE_VNC_SERVICE
}

function UPDATE_VNC_SERVER {
  echo -n "Iniciando"
  APT_UPDATE
  DEACTIVATE_VNC_SERVICE
  CREATE_VNC_SERVER
  CLEANUP_INSTALL
  ACTIVATE_VNC_SERVICE
}

function CHANGE_VNC_SETTINGS() {
  GREP_VARIABLES
  CONFIG $1
}

function START_VNC {
  CHECK_SERVICE_INACTIVE
}

function STOP_VNC {
  CHECK_SERVICE_ACTIVE
}

function ACTIVATE_VNC_SERVICE {
  CHECK_SERVICE_DISABLED
  CHECK_SERVICE_INACTIVE
}

function DEACTIVATE_VNC_SERVICE {
  CHECK_SERVICE_ACTIVE
  CHECK_SERVICE_ENABLED
}

function REMOVE_VNC_SERVER_AND_SERVICE {
  DEACTIVATE_VNC_SERVICE
  systemctl daemon-reload
  REMOVE_FILES
}

function GREP_VARIABLES {  
  port=$(egrep "port" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  framerate=$(egrep "frame-rate" /etc/dispmanx_vncserver.conf | egrep -o [0-9]+)
  mypassword=$(egrep "password" /etc/dispmanx_vncserver.conf | cut -d'"' -f2)
}

function COPY_CONF {
  cd /home/osmc/dispmanx_vnc-master
  
  sudo cp dispmanx_vncserver.conf.sample /etc/dispmanx_vncserver.conf
  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = 5900;/'
}

function COPY_BIN {
  REMOVE_BIN
  cd /home/osmc/dispmanx_vnc-master
  
  sudo cp dispmanx_vncserver /usr/bin
}

function SET_VARIABLES {
  sed -i /etc/dispmanx_vncserver.conf -e 's/port =.*/port = '"$port"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/frame-rate =.*/frame-rate = '"$framerate"';/'
  sed -i /etc/dispmanx_vncserver.conf -e 's/password =.*/password = "'"$mypassword"'";/'
}

function APT_INSTALL {
  apt-get update 1> /dev/null
  apt-get install -y build-essential rbp-userland-dev-osmc libvncserver-dev libconfig++-dev unzip 1> /dev/null
}

function CLEANUP_INSTALL {
  cd /home/osmc/
  
  if [ -d "dispmanx_vnc-master/" ];
    then
      rm -rf dispmanx_vnc-master/
  fi
  
  if [ -e "master.zip" ];
    then
      rm -f master.zip
  fi
}

function REMOVE_FILES {
  REMOVE_CONF
  REMOVE_BIN
  REMOVE_SERVICE_FILE
}

function REMOVE_CONF {
  cd /etc
  
  if [ -e "dispmanx_vncserver.conf" ];
    then
      rm -f dispmanx_vncserver.conf
  fi
}

function REMOVE_BIN {
  cd /usr/bin
  
  if [ -e "dispmanx_vncserver" ];
    then
      rm -f dispmanx_vncserver
  fi
}

function REMOVE_SERVICE_FILE {
  cd /etc/systemd/system
  
  if [ -e "dispmanx_vncserver.service" ];
    then
      rm -f dispmanx_vncserver.service
  fi
}

function GET_DISPMANX {
  cd /home/osmc/
  
  wget -q https://github.com/patrikolausson/dispmanx_vnc/archive/master.zip
  unzip -q -u master.zip -d  /home/osmc/
}

function MAKE_DISPMANX {
  cd /home/osmc/dispmanx_vnc-master
  
  # --quiet para nao mostrar na tela
  make --quiet clean
  make --quiet
}

function CREATE_VNC_SERVER {
  GET_DISPMANX
  MAKE_DISPMANX
  COPY_BIN
}

function CREATE_SERVICE_FILE {
cat > "/etc/systemd/system/dispmanx_vncserver.service" <<-EOF
[Unit]
Description=VNC Server
After=network-online.target
Requires=network-online.target

[Service]
Restart=on-failure
RestartSec=30
Nice=15
User=root
Group=root
Type=simple
ExecStartPre=/sbin/modprobe evdev
ExecStart=/usr/bin/dispmanx_vncserver
KillMode=process

[Install]
WantedBy=multi-user.target

EOF
}

function CONFIG () {
  #echo $1
  # Armazene dados na variável $VALUES
  VALUES=$(dialog --title "" \
         --stdout \
         --backtitle "Installing VNC-Server on OSMC" \
         --insecure \
         --ok-label Set \
         $1 \
         --output-separator $separator \
         --mixedform "Configuration" \
         10 50 0 \
        "Port:   (eg. 5900)" 1 2 "$port"        1 21 12 0 0 \
        "Framerate: (10-25)" 2 2 "$framerate"   2 21 12 0 0 \
        "VNC-Password:"      3 2 "$mypassword"  3 21 12 0 1 \
  )
  rep=$?
  
  # valores de exibicao recem-inseridos
  #echo "$VALUES"
  #echo "$response"
  
  port=$(echo "$VALUES" | cut -f 1 -d "$separator")
  framerate=$(echo "$VALUES" | cut -f 2 -d "$separator")
  mypassword=$(echo "$VALUES" | cut -f 3 -d "$separator")
  
  #echo "$port"
  #echo "$framerate"
  #echo "$mypassword"
  
  case $rep in
   0)   SET_VARIABLES
        DONE
        MENU
        ;;
   1)   MENU
        ;;
   255) MENU
        ;;
  esac
}

function MENU {
  # Armazene dados na variável $VALUES
  VALUE=$(dialog --backtitle "Instalando VNC-Server no OSMC" \
         --title "" \
         --stdout \
         --no-tags \
         --cancel-label "Sair" \
         --menu "Escolha uma opcao" 17 57 9 \
         "1" "Atualizacao do sistema OSMC (com reinicializacao forcada)" \
         "2" "Instale o servidor e servico VNC" \
         "3" "Remover servidor e servico VNC" \
         "4" "Atualizar servidor VNC (obrigatorio apos uma atualizacao do kernel)" \
         "5" "Alterar configuracao VNC" \
         "6" "Inicie o VNC (manual, nao servico)" \
         "7" "Parar VNC (manual, nao servico)" \
         "8" "Ativar servico VNC" \
         "9" "Desativar servico VNC"
  )
  response=$?
  
  # valores de exibicao recem-inseridos
  #echo "$response"
  #echo "$VALUE"
  
  case $response in
   0)   OPTIONS
        ;;
   1)   EXIT
        ;;
   255) EXIT
        ;;
  esac
}

port=$2
framerate=$3
mypassword=$4

function HELP {
  echo "Este script deve ser executado como root: sudo $0"
  echo
  echo "Voce pode iniciar este script como GUI sem parametro ou usando o"
  echo "seguinte parâmetro para executá-lo no modo CLI:"
  echo
  echo "--system-update,      atualiza OSMC e o sistema (com reinicialização forcada)"
  echo "--install-vnc,        instale o VNC com tres parametros adicionais necessarios de porta,"
  echo "                      taxa de quadros e senha"
  echo "                      e.g. --install-vnc 5900 25 osmc"
  echo "--remove-vnc,         remove todos os arquivos do VNC"
  echo "--update-vnc,         recompilar o VNC apos uma atualizacao OSMC"
  echo "--change-config,      muda a configuracao com tres parametros adicionais necessarios"
  echo "                      porta, taxa de quadros e senha"
  echo "                      e.g. --change-config 5900 25 osmc"
  echo "--start-vnc,          inicia VNC-Server"
  echo "--stop-vnc,           para VNC-Server"
  echo "--activate-service,   ativar VNC como servico"
  echo "--deactivate-service, desabilita VNC como servico"
  echo "--help, this!"
  echo
}

case $1 in
  --system-update)      OSMC_UPATE;;
  --install-vnc)        INSTALL_VNC_SERVER_AND_SERVICE
                        SET_VARIABLES;;
  --remove-vnc)         REMOVE_VNC_SERVER_AND_SERVICE;;
  --update-vnc)         UPDATE_VNC_SERVER;;
  --change-config)      SET_VARIABLES;;
  --start-vnc)          START_VNC;;
  --stop-vnc)           STOP_VNC;;
  --activate-service)   ACTIVATE_VNC_SERVICE;;
  --deactivate-service) DEACTIVATE_VNC_SERVICE;;
  --clean-up)           CLEANUP_INSTALL;;
  --help)               HELP;;
  *)                    CHECK_ROOT
                        MENU;;
esac
