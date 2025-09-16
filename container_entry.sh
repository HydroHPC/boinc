#!/bin/bash

# TODO:
# Create exec scripts to dump db, restore db, create user, submitter, ...

CMD=$1

POS_ARGS=${@:2}

func_check_database () {
    echo "Wait for database answer..."
    for I in {1..5}
    do
        echo "Try $I"
        timeout 1 bash -c 'echo > /dev/tcp/$DB_HOST/3306'
        RESULT=$?
        if [[ $RESULT -ne 0 ]]; then
            sleep 1
        else
            break
        fi
    done
    if [[ $RESULT -ne 0 ]]; then
        echo "Database not reachable, stop..."
        exit 1
    fi
    echo "Database sucessfully reached!"
}

func_make_project () {
    cd /boinc/libexec/boinc-server-maker/tools/
    yes | ./make_project --srcdir /boinc/share/boinc-server-maker $@
    cd /boinc_project_root/
    ./bin/xadd
} 

func_create_user () {
    EMAIL=$1
    USERNAME=$2
    PASSWORD=$3
    echo "Setting up user $USERNAME"
    if test -z "$PASSWORD"; then
        echo "Generate random password, this user will not be able to connect"
        PASSWORD=$(openssl rand -base64 16)
    fi
    cd /boinc_project_root/html/inc
    php -r "include_once('../inc/user_util.inc'); make_user('$EMAIL','$USERNAME','$PASSWORD');"
}

func_create_submitter () {
    SUBMIT_USER=$1
    func_create_user $SUBMIT_USER@fake.na $SUBMIT_USER
    mkdir -p /boinc_project_secrets/submitter/
    touch /boinc_project_secrets/submitter/$SUBMIT_USER.txt
    cd /boinc_project_root
    ./bin/create_user_submit $@
}


func_start_server () {
    cd /boinc_project_root
    python ./bin/start $@
    apache2-foreground
}

func_init () {
    f
    if [ -n "$SUBMIT_USER" ]; then
        func_create_submitter $SUBMIT_USER  > /boinc_project_secrets/submitter/$SUBMIT_USER.txt
	fi
}




# Run one-time init logic (first-run detection)
# 1. Check if BOINC file are present (config.xml) -> create project files
if [ ! -f /boinc_project_root/config.xml ]; then
    echo "config.xml not found, trying create a new project"
    func_check_database
    func_make_project --drop_db_first --url_base $BOINC_URL --project_root /boinc_project_root/ --db_name $DB_NAME --db_user $DB_USER --db_passwd $DB_PASSWORD  --db_host $DB_HOST --user_name boincadm $PROJECT_NAME $PROJECT_NAME@$CORP 
fi

# 2. Check if DB present -> add platform and apps

echo "Start BOINC server"
func_start_server $POS_ARGS

