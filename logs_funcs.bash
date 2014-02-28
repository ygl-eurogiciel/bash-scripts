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
# Example to use these functions in a bash caller script:
#
# LOGFILE=your_log_filename.log
# source logfuncs.sh
# 
# Last Modification: 28 February 2014


# Description:
#  Remove existing log file.
# Args :
#  None
function drop_logs {
  [ ! -f ${LOGFILE} ] || rm ${LOGFILE}
}

# Description:
#  Header in log file, date and time.
# Args :
#  None
function logs_addheader {
  [ ! -f ${LOGFILE} ] || {
    #rm ${LOGFILE}
    echo "######## Session start at: `date` ########" | tee -a ${LOGFILE}
  }
}

# Description:
#  Footer in log file
# Args :
#  None
function logs_addfooter {
  [ ! -f ${LOGFILE} ] || {
    echo "######## Session finished at: `date` ########" | tee -a ${LOGFILE}
  }
}

# Description:
#  Launch a command line and catch stdio & stderr output in a log file.
# Args :
#  process_name arg1 arg2 ... argN
function process_and_logs {
  [ $# -eq 0 ] || {
    if [ ! "$1" == "echo" ]; then
      echo "  $ $*" | tee -a ${LOGFILE}
    fi

    if [ "$1" == "cd" ]; then
      $* 2>&1
    else
      $* 2>&1 | tee -a ${LOGFILE}
    fi
  }
}

#################################################################

