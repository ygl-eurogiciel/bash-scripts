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
# EMAIL_FAKE_SEND=0     # 0: normal mode 1: avoid mail to be sent (debug mode)
# source email_funcs.sh
# 
# Last Modification: 28 February 2014


# Description:
#  Send a mail with an attachment (optional)
# Args :
#  $1: Email subject
#  $2: Email content
#  $3: Email address
#  $4...n: (Optional) files to attach
function email_send_file {
  if [ $# -lt 3 ]; then
    echo "${FUNCNAME}(): Not enough arguments"
    return 1
  fi

  subject=$1; shift
  content=$1; shift
  address=$1; shift

  attachlist=""
  while [ $# -gt 0 ]; do
    if [ ! -f $1 ]; then
      echo "${FUNCNAME}(): attachment $1 not found."
    else
      attachlist="${attachlist} -a $1"
    fi
    shift
  done

  if [ ${EMAIL_FAKE_SEND} -eq 1 ]; then
    echo "${content}" \| mail ${attachlist} -s "${subject}" "${address}"
  else
    echo "${content}" | mail ${attachlist} -s "${subject}" "${address}"
  fi
}

#################################################################

