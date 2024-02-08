#!/bin/bash

# v.2024-02-08.PWD_FREE_FOR_GIT

# ПЕРЕМЕННЫЕ и КОНСТАНТЫ
# Назначение скрипта:
script_purpose="УСТАНОВКА и РЕГИСТРАЦИЯ ZABBIX-агента"
# Имя файла с Ansible-плейбуком (должен находиться в одной папке с этим скриптом):
yaml_filename="852-install-zabbix-agent.yaml"

# Массив с именами host-файлов для установки разных типов Ansible-агентов:
declare -a hosts_files=("hosts.linux" "hosts.windows" "hosts.snmp")

# ДЛЯ УСТАНОВКИ:
# Имя пользователя с адм.правами на установку агента (на узлах). БУДЕТ ЗАПРОШЕНО ДОПОЛНИТЕЛЬНО (здесь следует оставить пустое значение):
zabbix_install_user=""

# Пароль пользователя (на узлах). БУДЕТ ЗАПРОШЕН ДОПОЛНИТЕЛЬНО:
zabbix_install_password=""

# Сервер(ы) для подключения агента:
zabbix_install_server="zabbix-server.acme.com"

# Сервер(ы) для подключения к агенту:
zabbix_install_serveractive="zabbix-server.acme.com"

# ДЛЯ РЕГИСТРАЦИИ:
# FQDN сервера:
zabbix_register_server="zabbix-server.acme.com"

# Путь к сервису (UI) Zabbix на сервере.
# Например, если полный путь http(s)://имя.сервера/zabbix , то нужно указать url_path как "zabbix".
# Если сервис опубликован как "корневой" http(s)://имя.сервера/ , то нужно указать как "/".
zabbix_register_url_path="/"

# Имя пользователя с полномочиями регистрировать новые узлы (на сервере). БУДЕТ ЗАПРОШЕНО ДОПОЛНИТЕЛЬНО:
zabbix_register_user=""

# Пароль (на сервере). БУДЕТ ЗАПРОШЕН ДОПОЛНИТЕЛЬНО:
zabbix_register_password=""

# Режим отладки:
DEBUG_MODE=1

# Вспомогательные переменные.
# Для форматирования вывода в консоль (для текста: 'полужирный' и 'нормальный'):
bold=$(tput bold)
normal=$(tput sgr0)

script_name=$0
extra_options=""
script_flow=0

# Функция вывода строки текста "в цвете" (плюс перевод строки)
IRed='\e[0;91m'   # Красный
# IGreen='\e[0;92m' # Зелёный
IYellow='\e[0;93m' # Желтый
# IBlue='\e[0;94m' # Синий
# IMagenta='\e[0;95m' # Фиолетовый
# ICyan='\e[0;96m'  # Голубой
Color_Off='\e[0m' # Цвет по-умолчанию
printf_color() {
	printf "%b%s%b\n" "$1" "$2" "${Color_Off}"
}
# Пример:
# printf_color "${IRed}" "Текст красным..."

# Функция, которая показывает какие параметры будут использованы при запуске плейбука:
showruncondition() {
    printf "\nДля запуска плейбука %s будут использованы следующие параметры:\n \
    Сервер Zabbix для регистрации узлов: %s\n \
    Путь к сервису Zabbix: %s\n \
    Имя пользователя с полномочиями на добавление узлов: %s\n" \
		"${yaml_filename}" \
		"${bold}${zabbix_register_server}${normal}" \
		"${bold}${zabbix_register_url_path}${normal}" \
		"${bold}${zabbix_register_user}${normal}"
    if [[ -n ${extra_options} ]]; then
		printf "     Дополнительные опции запуска: %s\n" "${bold}${extra_options}${normal}"
    fi
}

# Функция, которая показывает как запускать скрипт:
showhelp() {
  printf "Как запускать:\n \
  %s [-install|-add|-help]\n \
  где, \n \
    %s -- актуальное имя файла, содержащее этот скрипт;\n \
    %s -- (необязательный параметр) запустить скрипт в режиме только установки zabbix-агента на хосты;\n \
    %s -- (необязательный параметр) запустить скрипт в режиме только добавления (регистрации) хостов на zabbix-сервере;\n \
    %s -- это информационное сообщение.\n \
    Если скрипт запущен без параметров, то будут выполнен в полном объеме (установка и добавление).\n \
    Если скрипт запущен без параметров или с параметром -add , то он запросит имя и пароль пользователя, имеющего право добавлять хосты.\n" \
    "${bold}${script_name}${normal}" \
    "${bold}${script_name}${normal}" \
    "${bold}-install${normal}" \
    "${bold}-add${normal}" \
    "${bold}-help${normal}"
}

# BEGIN OF SCRIPT

# Если указан любой параметр:
if [[ -n $1 ]]; then
    case $1 in
        -[i]*)
            extra_options=" -t install "
            printf_color "${IYellow}" "Внимание! Будет выполнена только установка (без регистрации)."
            script_flow=1
        ;;
        -[a]*)
            extra_options=" -t add-host "
            printf_color "${IYellow}" "Внимание! Будет выполнено только добавление (без установки)."
            script_flow=2
        ;;
        -[h]*|-\?)
            showhelp
            exit 10
        ;;
        *)
            printf_color "${IYellow}" "Аргументы командной строки не распознаны!"
            showhelp
            exit 11
        ;;
    esac
fi

if [[ ${DEBUG_MODE} -eq 1 ]]; then
    # Если включён режим отладки, то добавить к строке запуска параметр -vvv
    extra_options="${extra_options}"" -vvv "
fi


if [[ ${script_flow} = 0 || ${script_flow} = 1 ]]; then
    # Получение имени пользователя (на хостах):
    printf "Для установки Zabbix-агента на узлах необходимо указать имя пользователя с административными полномочиями.\n"
    read -r -p "Введите имя пользователя (или нажмите [Enter] для выхода): " zabbix_install_user
    if [[ -z ${zabbix_install_user} ]]; then
        # Если пользователь для узлов указан не был, то прервать выполнение скрипта:
        printf_color "${IYellow}" "Имя пользователя не введёно. Выход из скрипта."
        exit 1
    fi
    # Получение пароля (на хостах):
    read -r -p "Введите пароль (или нажмите [Enter] для выхода): " -s zabbix_install_password
    if [[ -n ${zabbix_install_password} ]]; then
        echo "******"
    else
        # Если пароль указан не был, то прервать выполнение скрипта
        printf_color "${IRed}" "Пароль не введён. Выход из скрипта."
        exit 2
    fi
fi

if [[ ${script_flow} = 0 || ${script_flow} = 2 ]]; then
    # Получение имени пользователя (на сервере):
    printf "Для публикации на сервере  (%s) сведений об узлах, на которых (будут) установлены zabbix-агенты, \
необходимо указать имя пользователя с соответствующими полномочиями.\n" \
        "${zabbix_register_server}"
    read -r -p "Введите имя пользователя (или нажмите [Enter] для выхода): " zabbix_register_user
    if [[ -z ${zabbix_register_user} ]]; then
        # Если пользователь для сервера указан не был, то прервать выполнение скрипта:
        printf_color "${IYellow}" "Имя пользователя не введёно. Выход из скрипта."
        exit 3
    fi
    # Получение пароля (на сервере):
    read -r -p "Введите пароль (или нажмите [Enter] для выхода): " -s zabbix_register_password
    if [[ -n ${zabbix_register_password} ]]; then
        echo "******"
    else
        # Если пароль указан не был, то прервать выполнение скрипта
        printf_color "${IRed}" "Пароль не введён. Выход из скрипта."
        exit 4
    fi
fi


# Вывод информации о предстоящем запуске (если включён режим отладки):
if [[ ${DEBUG_MODE} -eq 1 ]]; then showruncondition; fi #

# Установка на Windows:

ansible-playbook -i "${hosts_files[1]}" "${yaml_filename}" \
                  "${extra_options}" \
                  --extra-vars "zabbix_install_user=${zabbix_install_user} \
                   zabbix_install_password=${zabbix_install_password} \
                   zabbix_install_server=${zabbix_install_server} \
                   zabbix_install_serveractive=${zabbix_install_serveractive} \
                   zabbix_register_server=${zabbix_register_server} \
                   zabbix_register_user=${zabbix_register_user} \
                   zabbix_register_password=${zabbix_register_password} \
                   zabbix_register_url_path=${zabbix_register_url_path} \
                   "

# Установка на Linux:
# ansible-playbook -i "${hosts_files[0]}" "${yaml_filename}"

# Регистрация SNMP:
# ansible-playbook -i "${hosts_files[2]}" "${yaml_filename}"


# Clear garbage:
unset script_purpose
unset yaml_filename
unset hosts_files
unset zabbix_install_user
unset zabbix_install_password
unset zabbix_install_server
unset zabbix_install_serveractive
unset zabbix_register_server
unset zabbix_register_url_path
unset zabbix_register_user
unset zabbix_register_password

unset script_name
unset extra_options
unset script_flow
unset bold
unset normal
unset IRed
unset IGreen
unset IYellow
unset IBlue
unset IMagenta
unset ICyan
unset Color_Off

# END OF SCRIPT