#!/bin/bash

# RUN IT AS:
#   source scriptname.sh 
# OR
#   . scriptname.sh

# Reminder:
# Prepare virtual environment (in current dir):
#  python3 -m venv venv
#  . activate
#  pip install -r requrements.txt

BASEDIR=$(dirname "$0")

if [[ "$0" = "${BASH_SOURCE}" ]]; then
    echo "Needs to be run using source: . activatevenv.sh"

else
    echo "VIRTUAL ENVIRONMENT WILL BE ACTIVATED AS:"
    echo " source ${BASEDIR}/venv/bin/activate"

    VENVPATH="venv/bin/activate"
    if [[ $# -eq 1 ]]; then 
        if [[ -d $1 ]]; then
            VENVPATH="$1/bin/activate"
        else
            echo "Virtual environment $1 not found"
            return
        fi

    elif [[ -d "venv" ]]; then 
        VENVPATH="venv/bin/activate"

    elif [[ -d "env" ]]; then 
        VENVPATH="env/bin/activate"
    fi

    echo "Activating virtual environment ${VENVPATH}"
    source "${VENVPATH}"

    echo "HOW TO DEACTIVATE AFTER ALL?"
    echo "Just type in console (in current dir):"
    echo "deactivate"
    echo 

fi

# If you wish to run project instantly:
# python $BASEDIR/my_app.py

# END OF SCRIPT
