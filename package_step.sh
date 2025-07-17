#!/bin/bash
BOINC_SRC=$1
BOINC_DEST=$2

#PYVER=$(python -c "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')")


cp -r $BOINC_SRC/html/project.sample $BOINC_DEST/share/boinc-server-maker/html/
mkdir $BOINC_DEST/share/boinc-server-maker/sched
cp $BOINC_SRC/sched/pshelper $BOINC_DEST/share/boinc-server-maker/sched/
