#!/bin/bash
#
# Copyright 2014, Eurogiciel.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# native
#
# Last Modification: 03 March 2014

###
### Variables ###
###

## Default configuration file
CONFIG_FILE="xwalk_releasebot.conf"
source ${CONFIG_FILE}
#PAUSE_FILE=pause_git_sync



###
### Functions ###
###

# Logfile bash functions:
LOGFILE=${PWD}/.xwalk-releaser.log
source logs_funcs.bash

# Email bash functions:
EMAIL_FAKE_SEND=0
source email_funcs.bash

# Description:
#  Launch Rsync to perform the upstream tree snapshot for delivery on Tizen.org
# Args :
#  $1: XWalk src/ directory
#  $2: Snapshot destination directory
function snapshot_with_rsync {
  [ $# != 2 ] && {
    echo "${FUNCNAME}(): Not enough args"
    exit 1
  }

  [ -d $1/xwalk ] || {
    echo "${FUNCNAME}(): Wrong path \$1"
    exit 1
  }

  mkdir -p $2

  process_and_logs echo "Will sync following dirs:"
  process_and_logs echo " Xwalk src dir = $1"
  process_and_logs echo " Tizen.org dest dir = $2"
  process_and_logs echo ""
  process_and_logs echo "rsync in progress:"
  time rsync -a --delete --force --delete-excluded --exclude '.git*' --exclude '.svn' $1 $2
  process_and_logs echo ""
  process_and_logs echo "done."

  #Import packging (gbs do not allow link.)
  if [ -d $1/xwalk/packaging ]; then
    rm -rf $2/packaging
    mkdir -p $2/packaging
    cp -a $1/xwalk/packaging/* $2/packaging/
    rm -f $2/packaging/gbp*
  else
    process_and_logs echo "Warning: packaging directory not found in upstream tree. Ignoring sync in destination dir"
  fi
}

function prepare_commit_after_sync {
  [ $# != 1 ] && {
    echo "${FUNCNAME}(): Not enough args"
    exit 1
  }

  # Display some informations:
  process_and_logs echo "Source code as been duplicated in $1"
  process_and_logs echo "Here are some tips for next steps :"
  process_and_logs echo ""
  process_and_logs echo "First go to dest dir:"
  process_and_logs echo "   cd $1"
  process_and_logs echo "You can see changes using:"
  process_and_logs echo "   git status"
  process_and_logs echo "You can stage all changes:"
  process_and_logs echo "   git add -u"
  process_and_logs echo "   git add ."
  process_and_logs echo "You can commit changes adding a message refering to upstream version:"
  process_and_logs echo ""
  VERSION_FILE=$1/src/xwalk/VERSION
  UPSTREAM_COMMITID=$(cd $1/src/xwalk; git log | head -1 | cut -d ' ' -f 2 -; cd ${OLDPWD}; )
  [ -f ${VERSION_FILE} ] && {
    MAJOR_V=$(grep MAJOR ${VERSION_FILE} | cut -d '=' -f 2 -)
    MINOR_V=$(grep MINOR ${VERSION_FILE} | cut -d '=' -f 2 -)
    BUILD_V=$(grep BUILD ${VERSION_FILE} | cut -d '=' -f 2 -)
    PATCH_V=$(grep PATCH ${VERSION_FILE} | cut -d '=' -f 2 -)
    process_and_logs echo "   git commit -sm \"Upstream version ${MAJOR_V}.${MINOR_V}.${BUILD_V}.${PATCH_V}"
    process_and_logs echo ""
    process_and_logs echo "Upstream commit-id ${UPSTREAM_COMMITID}\""
  }
  process_and_logs echo ""
  process_and_logs echo "Or on Tizen.org:"
  process_and_logs echo "  git push origin HEAD:refs/for/master"
}


###
### Script entry point ###
###

# Uncomment for bash debug mode
# set -x

error_occurs=0
delivery_to_do=0

drop_logs
logs_addheader

# Initial checks
which git   > /dev/null || { process_and_logs echo "Error: git is not installed. Please install it before using this script."   ; error_occurs=1; }
which wget  > /dev/null || { process_and_logs echo "Error: wget is not installed. Please install it before using this script."  ; error_occurs=1; }
which mail  > /dev/null || { process_and_logs echo "Error: mail is not installed. Please install MUA before using this script." ; error_occurs=1; }
which rsync > /dev/null || { process_and_logs echo "Error: Rsync is not installed. Please install it before using this script." ; error_occurs=1; }


[ ${error_occurs} -eq 0 ] && for (( i=0 ; $i < ${#URL_FILES_COMMITID[@]} ; i++ ))
do
  process_and_logs echo "--------------"
  process_and_logs echo "Retrieve commit-id file from ${URL_FILES_COMMITID[$i]}"

  commitid_filename=$(basename ${URL_FILES_COMMITID[$i]})

  # Remove previously download SHA-1 local file.
  [ -f ${commitid_filename} ] && process_and_logs rm ${commitid_filename}

  process_and_logs wget ${URL_FILES_COMMITID[$i]} || error_occurs=1
  if [ ${error_occurs} -eq 1 ]; then
    process_and_logs echo "Error: file catch failed, abording"
    error_occurs=1
    continue
  fi

  # Parse commit-id file to catch latest upstream version.
  new_commitid=$(cat ${commitid_filename})

  process_and_logs echo "### Catching current commit-id in ${GIT_REPOS_PATH[$i]}"
  process_and_logs cd ${GIT_REPOS_PATH[$i]}

  commitid=$(git log | head -1 | cut -d ' ' -f 2)
  process_and_logs echo "###   current commit-id: ${commitid}"
  process_and_logs echo "###       new commit-id: ${new_commitid}"

  if [ "${commitid}" != "${new_commitid}" ]; then
    delivery_to_do=1

    process_and_logs git fetch --all -p || error_occurs=1
    process_and_logs echo git reset --hard || error_occurs=1
    process_and_logs echo git checkout ${new_commitid} || error_occurs=1

    process_and_logs cd ${OLDPWD}

    # Specific Gclient calls (surely XWalk only).
    if [ ${error_occurs} -eq 0 ] && [ ! -z "${CALL_GCLIENT[$i]}" ]; then
      echo "### Call gclient sync"

      process_and_logs cd ${CALL_GCLIENT[$i]}

      # Update Eurogiciel scripts git repo
      process_and_logs git fetch --all -p || error_occurs=1

      # Reset any previous modified file for .gclient
      process_and_logs git checkout -- .gclient || error_occurs=1

      # Modify .gclient xwalk file to point on new SHA-1
      process_and_logs cp .gclient .gclient.orig
      process_and_logs echo "  $ sed \"s|origin/master|${new_commitid}|\" .gclient.orig \> .gclient"
      sed "s|origin/master|${commitid}|" .gclient.orig > .gclient

      PATH=${PWD}/depot_tools:$PATH

      # Launch gclient
      process_and_logs gclient sync -v || error_occurs=1

      # This will fetch all the other source files but not run any hooks.
      process_and_logs gclient sync -v --gclientfile=.gclient-xwalk --nohooks || error_occurs=1

      # Generate the LASTCHANGE files.
      source_root=$(pwd)
      process_and_logs python $source_root/src/build/util/lastchange.py \
             -o $source_root/src/build/util/LASTCHANGE \
             -s $source_root/src || error_occurs=1

      process_and_logs python $source_root/src/build/util/lastchange.py \
             -o $source_root/src/build/util/LASTCHANGE.blink \
             -s $source_root/src/third_party/WebKit || error_occurs=1

      process_and_logs cd ${OLDPWD}

      # FIXME: Hardcoded path to remove
      [ -d "${CALL_GCLIENT[$i]}/Tizen_Crosswalk-tizen.org" ] && {
        process_and_logs echo "### Snapshot with rsync" 
        snapshot_with_rsync "${CALL_GCLIENT[$i]}/src" "${CALL_GCLIENT[$i]}/Tizen_Crosswalk-tizen.org" || error_occurs=1

        prepare_commit_after_sync ${CALL_GCLIENT[$i]}/Tizen_Crosswalk-tizen.org

        process_and_logs echo ""
        process_and_logs echo "git push on Tizen.org is ready... need a human to do it for now !"
      }
    fi

    [ ${error_occurs} -eq 0 ] && process_and_logs echo "### Sync done."
  else
    process_and_logs echo "### Already in sync. Nothing to do."
    process_and_logs cd ${OLDPWD}
  fi
done

logs_addfooter

# Send mail if required to all maintainers
for (( i=0 ; $i < ${#MAINTAINERS_EMAILS[@]} ; i++ ))
do
  if [ ${error_occurs} -eq 1 ]; then
    echo "Sending error status by mail to ${MAINTAINERS_EMAILS[$i]}"
    email_send_file "XWalk Release bot *error*" "$0: Error detected while running the bot. Cf. log attached" ${MAINTAINERS_EMAILS[$i]} ${LOGFILE}
  fi

  if [ ${delivery_to_do} -eq 1 ]; then
    echo "Sending information status by mail to ${MAINTAINERS_EMAILS[$i]}"
    email_send_file "XWalk Release bot *action needed*" "$0: Some commit-id have been updated on upstream servers. Cf. log attached" ${MAINTAINERS_EMAILS[$i]} ${LOGFILE}
  fi
done

exit 0
#################################################################


