#!/bin/bash

#   TBS: tbs
#   QRR: bunka
#   LFR: nippon
#   INT: inter fm
#   FMT: tokyo fm
#   FMJ: j-wave
#   JORF: radio nippon
#   RN1: radio nikkei 1
#   RN2: radio nikkei 2
#   HOUSOU-DAIGAKU: housou daigaku
#   IBS: ibraki
#   YFM: fm yokohama
#   NACK5: nack5
#   BAYFM78: bayfm
#   FMGUNMA: fm gunma
#   RADIOBERRY: radio berry

workdir=/tmp/`basename $0`
date=`date '+%Y-%m-%d-%H:%M'`
playerurl=http://radiko.jp/apps/js/flash/myplayer-release.swf
streamserver=rtmpe://f-radiko.smartstream.ne.jp

playerfile=${workdir}/player.swf
keyfile=${workdir}/authkey.png
auth1_fms=${workdir}/auth1_fms
auth2_fms=${workdir}/auth2_fms

if [ $# -ne 2 ]; then
  exit 1
fi

station=$1
DURATION=`expr $2 \* 60`
test -d ${workdir} || mkdir ${workdir}

#
# get player
#
if [ ! -f $playerfile ]; then
  wget -q -O $playerfile $playerurl

  if [ $? -ne 0 ]; then
    echo "failed get player"
    exit 1
  fi
fi

#
# get keydata (need swftool)
#
if [ ! -f $keyfile ]; then
  swfextract -b 12 $playerfile -o $keyfile

  if [ ! -f $keyfile ]; then
    echo "failed get keydata"
    exit 1
  fi
fi

test -f ${auth1_fms} && rm -f ${auth1_fms}

#
# access auth1_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_ts" \
     --header="X-Radiko-App-Version: 4.0.0" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --post-data='\r\n' \
     --no-check-certificate \
     --save-headers \
     -P ${workdir} \
     https://radiko.jp/v2/api/auth1_fms

if [ $? -ne 0 ]; then
  echo "failed auth1 process"
  exit 1
fi

#
# get partial key
#
authtoken=`perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)' ${auth1_fms} 2> /dev/null`
offset=`perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)' ${auth1_fms} 2> /dev/null`
length=`perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)' ${auth1_fms} 2> /dev/null`

partialkey=`dd if=${keyfile} bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey:

${partialkey}"

rm -f ${auth1_fms}

test -f ${auth2_fms} && rm -f ${auth2_fms}

#
# access auth2_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_ts" \
     --header="X-Radiko-App-Version: 4.0.0" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-AuthToken: ${authtoken}" \
     --header="X-Radiko-PartialKey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     -P ${workdir} \
     https://radiko.jp/v2/api/auth2_fms

if [ $? -ne 0 -o ! -f ${auth2_fms} ]; then
  echo "failed auth2 process"
  exit 1
fi

echo "authentication success"
areaid=`perl -ne 'print $1 if(/^([^,]+),/i)' ${auth2_fms} 2> /dev/null`
echo "areaid: ${areaid}"

rm -f ${auth2_fms}

#
# rtmpdump
#
/usr/bin/rtmpdump -v \
         -r "${streamserver}" \
         --playpath "simul-stream.stream" \
         --app "${station}/_definst_" \
         -W ${playerurl} \
         -C S:"" -C S:"" -C S:"" -C S:${authtoken} \
         --live \
         --buffer 24000 \
         --quiet \
         --stop ${DURATION} | \
cvlc --sout '#standard{access=http,mux=asf,dst=:8000}' - vlc://quit
