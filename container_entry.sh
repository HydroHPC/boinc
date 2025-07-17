#!/bin/bash

# TODO:
# Create exec scripts to dump db, restore db, create user, submitter, ...

CMD=$1
HELP="
Entrypoint for BOINC server.

Usage:
- serve: Start the BOINC server with start script in the /boinc_project_root/bin directory
- make_project: Create a BOINC project in /boinc_project_root and initialize database
- update_apps: Create and update BOINC apps with new changes in the apps directory
- create_user: Create a user with the given username and password
- create_submitter: Grant user right to submit job
"

POS_ARGS=${@:2}

func_check_database () {
    # Inspired from wait-for-it (https://github.com/vishnubob/wait-for-it/)
    echo "Wait for database answer..."
    WAITFORIT_TIME=5
    timeout $WAITFORIT_TIME bash -c 'echo > /dev/tcp/$DB_HOST/3306'
    WAITFORIT_RESULT=$?
    if [[ $WAITFORIT_RESULT -ne 0 ]]; then
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
    cd /boinc_project_root
    ./bin/create_user_submit $@
}

func_init () {
	if [ -n "$INITIATE_PROJECT" ]; then
        func_check_database
	    func_make_project --delete_prev_inst --drop_db_first --url_base $BOINC_URL --project_root /boinc_project_root/ --db_name $DB_NAME --db_user $DB_USER --db_passwd $DB_PASSWORD  --db_host $DB_HOST --user_name boincadm $PROJECT_NAME $PROJECT_NAME@$CORP 
	    
	    if [ -n "$SUBMIT_USER" ]; then
            func_create_user $SUBMIT_USER@fake.na $SUBMIT_USER
            mkdir -p /boinc_project_secrets/submitter/
            touch /boinc_project_secrets/submitter/$SUBMIT_USER.txt
            func_create_submitter $SUBMIT_USER  > /boinc_project_secrets/submitter/$SUBMIT_USER.txt
        fi
	fi
}



# Run one-time init logic (first-run detection)
# TODO if initialization asked
# 1. Check if BOINC file are present (config.xml, project.xml, ...) -> create project files
# 2. Check if DB present -> add platform and apps
# 3. Optional: create submitter
# Always update apps on restart ? Or if a flag ?
if [ ! -f /boinc_project_root/.initialized ]; then
    echo "Running first-time init tasks..."
    func_init
    touch /boinc_project_root/.initialized
fi


case $CMD in

  make_project)
    func_make_project $POS_ARGS
    ;;

  serve)
    # Handle SIGTERM
    #trap "cd /boinc_project_root && ./bin/stop && exit 0" SIGTERM
    # Optional: Run one-time init logic (first-run detection)
    echo "Start BOINC server"
    cd /boinc_project_root
    python ./bin/start $POS_ARGS
    apache2-foreground
    ;;
  
  update_apps)
    cd /boinc_project_root
    ./bin/create_apps
    ./bin/update_versions
    ;;
  
  create_user)
    func_create_user $POS_ARGS
    ;;
  
  create_submitter)
    func_create_submitter $POS_ARGS
    ;;
  
  restore_db)
    #TODO
    ;;
  
  dump_db)
    #TODO
    ;;
  
  help)
    echo -e "$HELP"
    ;;

  *)
    echo "Unknown command: $CMD"
    ;;
esac

