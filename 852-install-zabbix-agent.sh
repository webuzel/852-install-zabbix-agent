#!/usr/bin/env bash

# v.2024-02-13-GIT-EDITION

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
DEBUG_MODE=0

# Вспомогательные переменные.
# Для форматирования вывода в консоль (для текста: 'полужирный' и 'нормальный'):
bold=$(tput bold)
normal=$(tput sgr0)

script_name=$0
extra_options=""
script_flow=0
script_yes_answer=0

# Функция вывода строки текста "в цвете" (плюс перевод строки)
# Переменные (константы) для обозначения цветовых аттрибутов текста (неиспользуемые в данном скрипте закомментированы):
IRed='\e[0;91m'   # Красный
IYellow='\e[0;93m' # Желтый
# IGreen='\e[0;92m' # Зелёный
# IBlue='\e[0;94m' # Синий
# IMagenta='\e[0;95m' # Фиолетовый
# ICyan='\e[0;96m'  # Голубой
Color_Off='\e[0m' # Цвет по-умолчанию
printf_color() {
    printf "%b%s%b\n" "$1" "$2" "${Color_Off}"
}
# Пример:
# printf_color "${IRed}" "Текст красным..."

# Функция, которая показывает какие параметры будут использованы при запуске ansible-плейбука:
showRunConditions() {
    printf "\n******************************************************************\n"
    printf "Для запуска плейбука %s будут использованы следующие параметры:\n" \
           "${yaml_filename}"
    # Если скрипт выполняется в полном объёме или только установка:
    if [[ ${script_flow} = 0 || ${script_flow} = 1 ]]; then
    printf \
        " Имя пользователя  с административными полномочиями на узлах: %s \n" \
        "${bold}${zabbix_install_user}${normal}"
    fi
    # Если скрипт выполняется в полном объёме или только регистрация:
    if [[ ${script_flow} = 0 || ${script_flow} = 2 ]]; then
    printf \
        " Сервер Zabbix для регистрации узлов: %s\n Путь к сервису Zabbix: %s\n Имя пользователя с полномочиями на добавление узлов: %s\n" \
        "${bold}${zabbix_register_server}${normal}" \
        "${bold}${zabbix_register_url_path}${normal}" \
        "${bold}${zabbix_register_user}${normal}"
    fi
    if [[ -n ${extra_options} ]]; then
        printf " Дополнительные опции запуска: %s\n" "${bold}${extra_options}${normal}"
    fi
    printf "******************************************************************\n"
}

# Функция, которая показывает как запускать скрипт:
showHelp() {
    printf " Назначение: %s\n" "${script_purpose}"
    printf " Как запускать:\n \
  bash %s [-install|-add|-help] [-yes] [-debug]\n \
  где, \n \
    %s -- актуальное имя файла, содержащее этот скрипт;\n \
    %s -- (необязательный параметр) запустить скрипт в режиме только установки zabbix-агента на хосты;\n \
    %s -- (необязательный параметр) запустить скрипт в режиме только добавления (регистрации) хостов на zabbix-сервере;\n \
    %s -- это информационное сообщение;\n \
    %s -- (необязательный параметр) выполнение скрипта без дополнительных вопросов;\n \
    %s -- (необязательный параметр) выполнение скрипта в режиме отладки (больше диагностических сообщений).\n \
Если скрипт запущен без параметров, то будут выполнен в полном объеме (установка и добавление).\n \
В процессе выполнения скрипт запросит реквизиты учётных записей, имеющих право выполнять установку и регистрацию.\n" \
    "${bold}${script_name}${normal}" \
    "${bold}${script_name}${normal}" \
    "${bold}-i${normal}nstall" \
    "${bold}-a${normal}dd" \
    "${bold}-h${normal}elp" \
    "${bold}-y${normal}es" \
    "${bold}-d${normal}ebug"
}


# Для работы функций сохранение и извлечение параметров/значение в/из keyring может понадобиться установка дополнительных инструментов:
# sudo apt install libsecret-tools

# Функция для сохранения значения в хранилище gnome keyring (в "связку ключей"):
storeValueInKeyring() {
    # $1->servername $2->type $3->value 
    echo "$3" | secret-tool store --label="$2 for $1" server "$1" type "$2"
}

# Функция извлечения значения из хранилища gnome keyring:
retrieveValueFromKeyring() {
    # $1->servername $2 -> type
    secret-tool lookup server "$1" type "$2"
}

# Функция "разбора" параметров командной строки:
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case ${param} in
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
            -[y]*)
                script_yes_answer=1 # Ответ "Да" на все вопросы скрипта ("пропускать вопросы").
            ;;
            -[h]*|-\?)
                showHelp
                exit 10
            ;;
            -[d]*)
                DEBUG_MODE=1 # Включить "режим отладки".
            ;;
            *)
                printf_color "${IYellow}" "Аргументы командной строки не распознаны!"
                showHelp
                exit 11
            ;;
        esac
    done
}

# BEGIN OF SCRIPT

parse_params "$@"

if [[ ${DEBUG_MODE} -eq 1 ]]; then
    # Если включён режим отладки, то добавить к строке запуска параметр -vvv ("больше отладочной информации при работе ansible")
    extra_options="${extra_options}"" -vvv "
fi

# Если полная установка и регистрация или только установка на компьютеры:
if [[ ${script_flow} = 0 || ${script_flow} = 1 ]]; then
    # Получение имени пользователя (на хостах):
    printf "Для установки Zabbix-агента на узлах необходимо указать имя пользователя с административными полномочиями.\n"

    # Попытка прочитать значение из keyring:
    keyring_value1="$(retrieveValueFromKeyring "WindowsServer" "Name")"
    # Если значение оказалось "не нулевое", то:
    if [[ -n ${keyring_value1} ]]; then
        # Если скрипт работает без дополнительных вопросов:
        if [[ ${script_yes_answer} -eq 1 ]]; then
            # Присвоить переменной полученное значение:
            zabbix_install_user=${keyring_value1}
            # Если ранее было сохранено имя, то по-идее там был сохранён и пароль тоже:
            zabbix_install_password="$(retrieveValueFromKeyring "WindowsServer" "Password")"
            printf "Будет использовано ранее сохранённое имя (и пароль): %s.\n" "${zabbix_install_user}"
        else
            # Иначе, переспросить о необходимости использовать именно это имя:
            echo "Обнаружено ранее сохранённое имя такого пользователя (${keyring_value1}). Использовать в этот раз?"
            select yn in "Yes / Да" "No / Нет"; do
                case ${yn} in
                    Yes* )
                        # Если ответ положительный, то использовать прочитанное значение:
                        zabbix_install_user=${keyring_value1}
                        # Если ранее было сохранено имя, то и пароль тоже:
                        zabbix_install_password="$(retrieveValueFromKeyring "WindowsServer" "Password")"
                        break;;
                    No* )
                        # Если ответ отрицательный, то очистить переменные:
                        zabbix_install_user=""
                        keyring_value1=""
                        break;;
                    * ) echo "Необходимо выбрать вариант из предложенных (или Ctrl-C для прерывания выполнения)." ;;
                esac
            done
        fi
    fi
    # Если значение переменной пустое:
    if [[ -z ${zabbix_install_user} ]]; then
        read -r -p "Введите имя пользователя (или нажмите [Enter] для выхода): " zabbix_install_user
        if [[ -z ${zabbix_install_user} ]]; then
            # Если пользователь для узлов указан не был, то прервать выполнение скрипта:
            printf_color "${IYellow}" "Имя пользователя не введёно. Выход из скрипта."
            exit 1
        fi
    fi
    # Если пароль оказался пустой (в любом случае), то запросить его:   
    if [[ -z ${zabbix_install_password} ]]; then
        # Получение пароля (на хостах):
        read -r -p "Введите пароль (или нажмите [Enter] для выхода): " -s zabbix_install_password
        if [[ -n ${zabbix_install_password} ]]; then
            echo "******"
        else
            # Если пароль указан не был, то прервать выполнение скрипта:
            printf_color "${IRed}" "Пароль не введён. Выход из скрипта."
            exit 2
        fi
    fi
fi

# Если полная установка или только регистрация:
if [[ ${script_flow} = 0 || ${script_flow} = 2 ]]; then
    # Получение имени пользователя (на сервере):
    printf "Для публикации на сервере  (%s) сведений об узлах, на которых (будут) установлены zabbix-агенты, \
необходимо указать имя пользователя с соответствующими полномочиями.\n" \
        "${zabbix_register_server}"
    # Попытка прочитать значение из keyring:
    keyring_value2="$(retrieveValueFromKeyring "ZabbixServer" "Name")"
    # Если значение "не пустое", то:
    if [[ -n ${keyring_value2} ]]; then
        # Если скрипт работает в редиме "без вопросов", то:
        if [[ ${script_yes_answer} -eq 1 ]]; then
            # Присвоить переменной прочитанное значение:
            zabbix_register_user=${keyring_value2}
            # Если ранее было сохранено имя, то и пароль тоже:
            zabbix_register_password="$(retrieveValueFromKeyring "ZabbixServer" "Password")"
            printf "Будет использовано ранее сохранённое имя (и пароль): %s.\n" "${zabbix_register_user}"
        else
            echo "Обнаружено ранее сохранённое имя такого пользователя (${keyring_value2}). Использовать в этот раз?"
            select yn in "Yes / Да" "No / Нет"; do
                case ${yn} in
                    Yes* )
                        # Если ответ положительный, то присвоить переменной прочитанное значение:
                        zabbix_register_user=${keyring_value2}
                        # Если ранее было сохранено имя, то и пароль тоже:
                        zabbix_register_password="$(retrieveValueFromKeyring "ZabbixServer" "Password")"
                        break;;
                    No* )
                        # Если ответ отрицательный, то очистить переменные:
                        zabbix_register_user=""
                        keyring_value2=""
                        break;;
                    * ) echo "Необходимо указать номер варианта из предложенных (или Ctrl-C для прерывания выполнения)." ;;
                esac
            done
        fi
    fi
    # Если значение переменной не задано, то:
    if [[ -z ${zabbix_register_user} ]]; then
        read -r -p "Введите имя пользователя (или нажмите [Enter] для выхода): " zabbix_register_user
        if [[ -z ${zabbix_register_user} ]]; then
            # Если пользователь для сервера указан не был, то прервать выполнение скрипта:
            printf_color "${IYellow}" "Имя пользователя не введёно. Выход из скрипта."
            exit 3
        fi
    fi
    # Если пароль (для сервера) оказался пустой (в любом случае), то запросить его:   
    if [[ -z ${zabbix_register_password} ]]; then
        read -r -p "Введите пароль (или нажмите [Enter] для выхода): " -s zabbix_register_password
        if [[ -n ${zabbix_register_password} ]]; then
            echo "******"
        else
            # Если пароль указан не был, то прервать выполнение скрипта
            printf_color "${IRed}" "Пароль не введён. Выход из скрипта."
            exit 4
        fi
    fi
fi

# Вывод информации о предстоящем запуске (если включён режим отладки):
if [[ ${DEBUG_MODE} -eq 1 ]]; then 
    showRunConditions
    if [[ ${script_yes_answer} -eq 0 ]]; then
        echo "Продолжить выполнение?"
        select yn in "Yes / Да" "No / Нет"; do
            case ${yn} in
                Yes* ) break ;;
                No* ) exit 5 ;;
                * ) echo "Необходимо указать номер варианта из предложенных (или Ctrl-C также для прерывания выполнения)." ;;
            esac
        done
    fi
fi

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

# Сохранение введённых в процессе выполнения скрипта реквизитов доступа (а если ничего не вводилось, то не сохранять):
if [[ (( ${script_flow} = 0 || ${script_flow} = 1 ) && -z ${keyring_value1} ) || (( ${script_flow} = 0 ||  ${script_flow} = 2 ) && -z ${keyring_value2} ) ]]; then
    echo "Были введены имена и пароли. Сохранить их для следующих запусков скрипта?"
    select yn in "Yes / Да" "No / Нет"; do
        case ${yn} in
            Yes* ) 
                if [[ ( -z ${keyring_value1} ) ]]; then
                    storeValueInKeyring "WindowsServer" "Name" "${zabbix_install_user}"
                    storeValueInKeyring "WindowsServer" "Password" "${zabbix_install_password}"
                    if [[ ${DEBUG_MODE} -eq 1 ]]; then echo "Сохранены имя (${zabbix_install_user}) и пароль для доступа к Windows-компьютерам."; fi
                fi
                if [[ ( -z ${keyring_value2} ) ]]; then
                    storeValueInKeyring "ZabbixServer" "Name" "${zabbix_register_user}"
                    storeValueInKeyring "ZabbixServer" "Password" "${zabbix_register_password}"
                    if [[ ${DEBUG_MODE} -eq 1 ]]; then echo "Сохранены имя (${zabbix_register_user}) и пароль для регистрации хостов на Zabbix-сервере."; fi
                fi
                break
            ;;
            No* ) break ;;
            * ) echo "Необходимо выбрать вариант из предложенных (или Ctrl-C для прерывания выполнения)." ;;
        esac
    done
fi

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
unset script_yes_answer
unset keyring_value1
unset keyring_value2
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
