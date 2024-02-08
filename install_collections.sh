#!/bin/bash

# Установка системных библиотек:
sudo apt-get install python-dev-is-python3 libkrb5-dev krb5-user

# Установка библиотек для Python:
pip install -r requirements.txt

# Установка коллекций (можно добавить ключ --force для переустановки, если это требуется):
ansible-galaxy collection install -r requirements.yaml --force

# check:
ansible-galaxy collection list community.zabbix
