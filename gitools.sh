#!/bin/bash
#########################################################
# quick Google PageSpeed Insights API tool
# & gtmetrix api tool & webpagetest.org api usage
# written by George Liu (eva2000) https://centminmod.com
#
# https://developers.google.com/speed/docs/insights/v4/getting-started
# https://gtmetrix.com/api/
# https://sites.google.com/a/webpagetest.org/docs/advanced-features/webpagetest-restful-apis
#########################################################
# variables
#############
VER='1.5'
DT=$(date +"%d%m%y-%H%M%S")


# GET API Key from https://console.developers.google.com/
# by enabling PageSpeed Insights API and creating the
# API key from Credentials page. If you don't want to set the
# GOOGLE_API_KEY variable within this script, you can set it in
# gitools.ini config file which resides in same directory as gitools.sh
GOOGLE_API_KEY=''

CMD_OUTPUT='y'
JSON_OUTPUT='y'
SNAPSHOTS='n'
SCREENSHOT='n'

# Gtmetrix API settings
GTMETRIX='n'
GTEMAIL=''
GTAPIKEY=''
GTBROWSER_WIDTH='1366'
GTBROWSER_HEIGHT='768'
GTVIDEO='n'
# 1 = Vancouver, CA
# 2 = London, UK
# 3 = Sydney, Australia
# 4 = Dallas, USA
# 5 = Mumbai, India
# 6 = Sao Paulo, Brazil
# 7 = Hong Kong, China
GTLOCATION='4'
# Browsers
# 1 = Firefox
# 3 = Chrome
GTBROWSER='3'

# Webpagetest.org API Tests
WPT_LABEL=$(date +"%d%m%y-%H%M%S")
WPT_DIR='/home/wptresults'
WPT_RESULT_TESTSTATUS_LOG='/tmp/wpt-teststatus-check.log'
WPT_SHOW_HISTORY='y'
WPT_IGNORE_SSL='y'
WPT_RUNS='1'
WPT_LIGHTHOUSE='y'
WPT_APIURL='https://www.webpagetest.org/runtest.php'
WPT_APIKEY='YOUR_API_KEY'
WPT_LOCATION='Dulles:Chrome.Cable'
WPT_DULLES='y'
WPT_DULLES_3G='n'
WPT_DULLES_3G_S7='n'
WPT_CALIFORNIA='n'
WPT_FRANKFURT='n'
WPT_SINGAPORE='n'
WPT_SYDNEY='n'
WPT_DALLAS='n'
WPT_LONDON='n'
# wait time between API run and parsing
# result log
WPT_SLEEPTIME='15'

# slack channel
SLACK='n'
webhook_url=""       # Incoming Webhooks integration URL
channel="general"    # Default channel to post messages. '#' is prepended
username="psi-bot"   # Default username to post messages.
icon="ghost"         # Default emoji to post messages. Don't wrap it with ':'. See http://www.emoji-cheat-sheet.com; can be a url too.
#########################################################
# functions
#############
if [ -f gitools.ini ]; then
  . gitools.ini
fi

if [ ! -d "$WPT_DIR" ]; then
  mkdir -p "$WPT_DIR"
fi

if [ ! -f /usr/bin/jq ]; then
  if [ -d /etc/yum.repos.d ]; then
    yum -q -y install jq
  fi
  if [ -f /usr/bin/apt ]; then
    apt-get -y -q install jq
  fi
fi

if [[ "$SNAPSHOTS" = [Yy] ]]; then
  snapshots_state='true'
else
  snapshots_state='false'
fi

if [[ "$SCREENSHOT" = [Yy] ]]; then
  screenshot_state='true'
else
  screenshot_state='false'
fi

if [[ "$GTVIDEO" = [Yy] ]]; then
  gtvideo_state='1'
else
  gtvideo_state='0'
fi

if [[ "$WPT_IGNORE_SSL" = [yY] ]]; then
  ignore_ssl='&ignoreSSL=1'
else
  ignore_ssl=""
fi

if [[ "$WPT_SHOW_HISTORY" = [yY] ]]; then
  wpt_show_history='0'
else
  wpt_show_history='1'
fi

slacksend() {
  dt=$DT
  # message="$dt: This is posted to #$channel and comes from a bot named $username."
  message="$1"
  slack_fallback="$2"
  slack_title="$slack_fallback"
  slack_message_title="$slack_title"
  # curl -X POST --data-urlencode "payload={\"channel\": \"#$channel\", \"username\": \"$username\", \"text\": \"$message\", \"icon_emoji\": \":$icon:\"}" $webhook_url
  curl -X POST --data-urlencode "payload={\"channel\": \"#$channel\", \"username\": \"$username\", \"icon_emoji\": \":$icon:\", \"attachments\": [ { \"fallback\": \"${slack_fallback}\", \"color\": \"good\", \"fields\": [{ \"title\": \"$slack_message_title\", \"value\": \"${message}\", \"short\": false }] } ]}" $webhook_url
}

wpt_run() {
  WPT_URL=$1
  WPT_REGION=${2}
  WPT_SPEED=${3:-Cable}
  WPT_SPEED=$(echo $WPT_SPEED | awk '{print tolower($0)}')
  WPT_RESOLUTION_WIDTH=${4:-1920}
  WPT_RESOLUTION_HEIGHT=${5:-1200}
  prefix=$(echo $WPT_URL | awk -F '://' '{print $1}')
  domain=$(echo $WPT_URL | awk -F '://' '{print $2}')
  if [[ "$WPT_SPEED" = 'cable' ]]; then
    WPT_SPEED='Cable'
    WPT_SPEED_TXT='cable'
  elif [[ "$WPT_SPEED" = '3g' ]]; then
    WPT_SPEED='3G'
    WPT_SPEED_TXT='3g'
  elif [[ "$WPT_SPEED" = '4g' ]]; then
    WPT_SPEED='4G'
    WPT_SPEED_TXT='4g'
  elif [[ "$WPT_SPEED" = 'lte' ]]; then
    WPT_SPEED='LTE'
    WPT_SPEED_TXT='lte'
  elif [[ "$WPT_SPEED" = 'fios' ]]; then
    WPT_SPEED='FIOS'
    WPT_SPEED_TXT='fios'
  else
    WPT_SPEED='Cable'
    WPT_SPEED_TXT='cable'
  fi
  if [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'dulles-3g' )" = 'dulles-3g' ]]; then
    WPT_REGION_CMD='dulles-3g'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'dulles-s7-3g' )" = 'dulles-s7-3g' ]]; then
    WPT_REGION_CMD='dulles-s7-3g'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'dulles' )" = 'dulles' ]]; then
    WPT_REGION_CMD='dulles'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'california' )" = 'california' ]]; then
    WPT_REGION_CMD='california'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'frankfurt' )" = 'frankfurt' ]]; then
    WPT_REGION_CMD='frankfurt'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'singapore' )" = 'singapore' ]]; then
    WPT_REGION_CMD='singapore'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'sydney' )" = 'sydney' ]]; then
    WPT_REGION_CMD='sydney'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'dallas' )" = 'dallas' ]]; then
    WPT_REGION_CMD='dallas'
  elif [[ "$(echo $WPT_REGION | awk '{print tolower($0)}' | grep -o 'london' )" = 'london' ]]; then
    WPT_REGION_CMD='london'
  else
    WPT_REGION_CMD="none"
  fi
  if [[ "$WPT_DULLES_3G" = [yY] ]]; then
    WPT_SLEEPTIME='30'
    WPT_PROCEED='y'
    WPT_LOCATION='Dulles:MotoG4:3g'
    WPT_LOCATION_TXT='dulles-motog4-mobile.chrome.3g'
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='MotoG4_21'
  elif [[ "$WPT_DULLES_3G_S7" = [yY] ]]; then
    WPT_SLEEPTIME='30'
    WPT_PROCEED='y'
    WPT_LOCATION='Dulles:GalaxyS7:3g'
    WPT_LOCATION_TXT='dulles-galaxys7-mobile.chrome.3g'
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='Galaxy_S7_1'
  elif [[ "$WPT_DULLES" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="Dulles:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="dulles.chrome.${WPT_SPEED_TXT}"
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='VM3-06'
  elif [[ "$WPT_CALIFORNIA" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-us-west-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="california.ec2-us-west-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-8-84'
  elif [[ "$WPT_FRANKFURT" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-eu-central-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="frankfurt.ec2-eu-central-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-28-65'
  elif [[ "$WPT_SINGAPORE" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-ap-southeast-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="singapore.ec2-ap-southeast-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-39-48'
  elif [[ "$WPT_SYDNEY" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-ap-southeast-2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="sydney.ec2-ap-southeast-2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-7-201'
  elif [[ "$WPT_DALLAS" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="Texas2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="dallas.Texas2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='Dallas'
  elif [[ "$WPT_LONDON" = [yY] ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="London_EC2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="london.London_EC2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-8-123'
  fi
  ########################################################################
  # override options on command line
  if [[ "$WPT_REGION_CMD" = 'dulles-3g' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION='Dulles:MotoG4:3g'
    WPT_LOCATION_TXT='dulles-motog4-mobile.chrome.3g'
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='MotoG4_21'
  elif [[ "$WPT_REGION_CMD" = 'dulles-s7-3g' ]]; then
    WPT_SLEEPTIME='30'
    WPT_PROCEED='y'
    WPT_LOCATION='Dulles:GalaxyS7:3g'
    WPT_LOCATION_TXT='dulles-galaxys7-mobile.chrome.3g'
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='Galaxy_S7_1'
  elif [[ "$WPT_REGION_CMD" = 'dulles' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="Dulles:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="dulles.chrome.${WPT_SPEED_TXT}"
    # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='VM3-06'
  elif [[ "$WPT_REGION_CMD" = 'california' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-us-west-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="california.ec2-us-west-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-8-84'
  elif [[ "$WPT_REGION_CMD" = 'frankfurt' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-eu-central-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="frankfurt.ec2-eu-central-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-28-65'
  elif [[ "$WPT_REGION_CMD" = 'singapore' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-ap-southeast-1:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="singapore.ec2-ap-southeast-1.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-39-48'
  elif [[ "$WPT_REGION_CMD" = 'sydney' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="ec2-ap-southeast-2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="sydney.ec2-ap-southeast-2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-7-201'
  elif [[ "$WPT_REGION_CMD" = 'dallas' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="Texas2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="dallas.Texas2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='Dallas'
  elif [[ "$WPT_REGION_CMD" = 'london' ]]; then
    WPT_PROCEED='y'
    WPT_LOCATION="London_EC2:Chrome.${WPT_SPEED}"
    WPT_LOCATION_TXT="london.London_EC2.chrome.${WPT_SPEED_TXT}"
   # define specific testers for specific locales
    # for more consistent repeated testing runs
    # https://www.webpagetest.org/getTesters.php
    TESTER_CABLE='ip-172-31-8-123'
  fi
  if [[ "$WPT_LIGHTHOUSE" = [yY] ]]; then
    wpt_lighthouse_opt='&lighthouse=1'
  else
    wpt_lighthouse_opt=""
  fi
  if [[ "$WPT_PROCEED" = [yY] ]]; then
    WPT_LABEL="$WPT_LOCATION_TXT.$(date +"%d%m%y-%H%M%S")"
    WPT_RESULT_LOG="${WPT_DIR}/wpt-${WPT_LABEL}.log"
    WPT_SUMMARYRESULT_LOG="${WPT_DIR}/wpt-${WPT_LABEL}-summary.log"
    # WPT_TESTURL=$(echo "${WPT_APIURL}?k=$WPT_APIKEY&url=$WPT_URL&label=$WPT_LABEL&location=$WPT_LOCATION&runs=${WPT_RUNS}&fvonly=1&video=1&private=${wpt_show_history}&medianMetric=loadTime${wpt_lighthouse_opt}&width=${WPT_RESOLUTION_WIDTH}&height=${WPT_RESOLUTION_HEIGHT}${ignore_ssl}&f=xml&tester=${TESTER_CABLE}")
    WPT_TESTURL=$(echo "${WPT_APIURL}?k=$WPT_APIKEY&url=$WPT_URL&label=$WPT_LABEL&location=$WPT_LOCATION&runs=${WPT_RUNS}&fvonly=1&video=1&private=${wpt_show_history}&medianMetric=loadTime${wpt_lighthouse_opt}${ignore_ssl}&f=xml&tester=${TESTER_CABLE}")
    echo "curl -4s \"$WPT_TESTURL\"" > "$WPT_RESULT_LOG"
    curl -4s "$WPT_TESTURL" >> "$WPT_RESULT_LOG"
    WPT_USER_RESULTURL=$(grep -oP '(?<=<userUrl>).*(?=</userUrl>)' "$WPT_RESULT_LOG")
    WPT_USER_RESULTXMLURL=$(grep -oP '(?<=<xmlUrl>).*(?=</xmlUrl>)' "$WPT_RESULT_LOG")
    WPT_TESTIDA=$(grep -oP '(?<=<testId>).*(?=</testId>)' "$WPT_RESULT_LOG")
    echo
    echo "--------------------------------------------------------------------------------"
    echo "$WPT_LOCATION WPT Results"
    echo "--------------------------------------------------------------------------------"
    echo "Test ID: $WPT_TESTIDA"
    if [[ "$WPT_TESTIDA" ]]; then
      sleep "$WPT_SLEEPTIME"
      echo "$WPT_USER_RESULTURL"
    fi
    if [[ "$WPT_LIGHTHOUSE" = [yY] ]]; then
      WPT_LIGHTHOUSE_URL="https://www.webpagetest.org/lighthouse.php?test=$WPT_TESTIDA"
      echo "$WPT_LIGHTHOUSE_URL"
    fi
    if [[ "$WPT_SHOW_HISTORY" = [yY] ]]; then
      WPT_HISTORY_URL="https://www.webpagetest.org/testlog.php?days=1&filter=${domain}&all=on&video=on"
      echo "$WPT_HISTORY_URL"
    fi
    echo "$WPT_RESULT_LOG"
    WPT_RESULT_STATUSCODE=$(grep -oP '(?<=<statusCode>).*(?=</statusCode>)' "$WPT_RESULT_LOG")
    WPT_RESULT_STATUS=$(grep -oP '(?<=<statusText>).*(?=</statusText>)' "$WPT_RESULT_LOG")
    if [[ "$WPT_RESULT_STATUSCODE" -eq '100' || "$WPT_RESULT_STATUSCODE" -eq '101' || "$WPT_RESULT_STATUSCODE" -eq '200' ]]; then
      curl -4s "https://www.webpagetest.org/testStatus.php?f=xml&test=$WPT_TESTIDA" > "$WPT_RESULT_TESTSTATUS_LOG"
      WPT_RESULT_STATUSCODE=$(grep -oP '(?<=<statusCode>).*(?=</statusCode>)' "$WPT_RESULT_TESTSTATUS_LOG")
      WPT_RESULT_STATUS=$(grep -oP '(?<=<statusText>).*(?=</statusText>)' "$WPT_RESULT_TESTSTATUS_LOG")
      # check test result xml result status if Ok 200, proceed otherwise if 
      # Test Started 100 status or Waiting behind another test 101 status is found,
      # wait WPT_SLEEPTIME more to proceed
      while [[ "$WPT_RESULT_STATUSCODE" -eq '100' || "$WPT_RESULT_STATUSCODE" -eq '101' ]]; do
        sleep "$WPT_SLEEPTIME"
        if [[ "$WPT_RESULT_STATUSCODE" -eq '101' ]]; then
          sleep "$WPT_SLEEPTIME"
        fi
        curl -4s "https://www.webpagetest.org/testStatus.php?f=xml&test=$WPT_TESTIDA" > "$WPT_RESULT_TESTSTATUS_LOG"
        WPT_RESULT_STATUSCODE=$(grep -oP '(?<=<statusCode>).*(?=</statusCode>)' "$WPT_RESULT_TESTSTATUS_LOG")
        WPT_RESULT_STATUS=$(grep -oP '(?<=<statusText>).*(?=</statusText>)' "$WPT_RESULT_TESTSTATUS_LOG")
        echo "$WPT_RESULT_STATUS ($WPT_RESULT_STATUSCODE)"
        echo "waiting on results..."
      done
      if [[ "$WPT_RESULT_STATUSCODE" -eq '200' ]]; then
        WPT_USER_RESULTXMLURL=$(grep -oP '(?<=<xmlUrl>).*(?=</xmlUrl>)' "$WPT_RESULT_LOG")
        echo "$WPT_RESULT_STATUS ($WPT_RESULT_STATUSCODE)"
        echo "----"
        if [[ "$WPT_LIGHTHOUSE" = [yY] ]]; then
          # additional lighthouse metrics to parse
          waterfall_url=$(curl -4s "$WPT_USER_RESULTXMLURL" | grep -oP '(?<=<waterfall>).*(?=</waterfall>)' | grep -v thumb)
          echo "curl -4s "$WPT_USER_RESULTXMLURL" | egrep -m1 -m2 -m3 -m4 -m5 -m6 -m7 -m8 -m9 -m10 -m11 -m12 -m13 -m14 -m15 -m16 -m17 -m18 -m19 -m20 -m21 -m22 -m23 -m24 -m25 'loadTime|TTFB|requests>|render|fullyLoaded>|domElements|firstPaint>|domInteractive|SpeedIndex|visualComplete|<lighthouse.Performance.|chromeUserTiming.firstContentfulPaint|chromeUserTiming.firstMeaningfulPaint|chromeUserTiming.domComplete'  | sed -e 's|<||' -e 's|>| |g' -e 's|<\/.*| |'" >> "$WPT_RESULT_LOG"
          curl -4s "$WPT_USER_RESULTXMLURL" | egrep -m1 -m2 -m3 -m4 -m5 -m6 -m7 -m8 -m9 -m10 -m11 -m12 -m13 -m14 -m15 -m16 -m17 -m18 -m19 -m20 -m21 -m22 -m23 -m24 -m25 'loadTime|TTFB|requests>|render|fullyLoaded>|domElements|firstPaint>|domInteractive|SpeedIndex|visualComplete|<lighthouse.Performance.|chromeUserTiming.firstContentfulPaint|chromeUserTiming.firstMeaningfulPaint|chromeUserTiming.domComplete'  | sed -e 's|<||' -e 's|>| |g' -e 's|<\/.*| |' > "$WPT_SUMMARYRESULT_LOG"
          echo "$waterfall_url" >> "$WPT_SUMMARYRESULT_LOG"
        else
          waterfall_url=$(curl -4s "$WPT_USER_RESULTXMLURL" | grep -oP '(?<=<waterfall>).*(?=</waterfall>)' | grep -v thumb)
          echo "curl -4s "$WPT_USER_RESULTXMLURL" | egrep -m1 -m2 -m3 -m4 -m5 -m6 -m7 -m8 -m9 -m10 -m11 -m12 -m13 -m14 -m15 -m16 -m17 -m18 -m19 -m20 'loadTime|TTFB|requests>|render|fullyLoaded>|domElements|firstPaint>|domInteractive|SpeedIndex|visualComplete|chromeUserTiming.firstContentfulPaint|chromeUserTiming.firstMeaningfulPaint|chromeUserTiming.domComplete'  | sed -e 's|<||' -e 's|>| |g' -e 's|<\/.*| |'" >> "$WPT_RESULT_LOG"
          curl -4s "$WPT_USER_RESULTXMLURL" | egrep -m1 -m2 -m3 -m4 -m5 -m6 -m7 -m8 -m9 -m10 -m11 -m12 -m13 -m14 -m15 -m16 -m17 -m18 -m19 -m20 'loadTime|TTFB|requests>|render|fullyLoaded>|domElements|firstPaint>|domInteractive|SpeedIndex|visualComplete|chromeUserTiming.firstContentfulPaint|chromeUserTiming.firstMeaningfulPaint|chromeUserTiming.domComplete'  | sed -e 's|<||' -e 's|>| |g' -e 's|<\/.*| |' > "$WPT_SUMMARYRESULT_LOG"
          echo "$waterfall_url" >> "$WPT_SUMMARYRESULT_LOG"
        fi

        cat "$WPT_SUMMARYRESULT_LOG" | tee -a "$WPT_RESULT_LOG"
        if [[ "$SLACK" = [yY] ]]; then
          send_message="$(cat $WPT_SUMMARYRESULT_LOG)"
          slacksend "Webpagetest.org Test: $WPT_LOCATION\n$WPT_URL\n$WPT_USER_RESULTURL\n$WPT_USER_RESULTXMLURL\n$WPT_LIGHTHOUSE_URL\n$WPT_HISTORY_URL\n$send_message" "$DT - $WPT_LOCATION"
        fi
        echo "----"
      else
        echo "$WPT_RESULT_STATUS ($WPT_RESULT_STATUSCODE)"
      fi
    else
      echo "Webpagetest failed..."
    fi
    echo "--------------------------------------------------------------------------------"
    echo
  fi
}

gt_run() {
  fulldomain=$1
  prefix=$(echo $fulldomain | awk -F '://' '{print $1}')
  domain=$(echo $fulldomain | awk -F '://' '{print $2}')
  # browser = 3 chrome
  # location = 4 dallas
  curl -4s --user $GTEMAIL:$GTAPIKEY --form url=${prefix}://${domain} --form x-metrix-adblock=0 --form x-metrix-video=$gtvideo_state --form browser=$GTBROWSER --form location=$GTLOCATION --form x-metrix-browser-width=$GTBROWSER_WIDTH --form x-metrix-browser-height=$GTBROWSER_HEIGHT --form x-metrix-throttle='5000/1000/30' https://gtmetrix.com/api/0.1/test | tee /tmp/gtmetrix.log
  echo "waiting on results..."
  sleep 30s
  gtmetrix_result=$(cat /tmp/gtmetrix.log | jq '.poll_state_url' | sed -e 's|\"||g')
  if [[ "$JSON_OUTPUT" = [yY] ]]; then
    {
    result_state=$(curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.state'| sed -e 's|\"||g')
    if [[ "$result_state" = 'completed' ]]; then
      curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.'
    else
      sleep 15s
      curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.'
    fi
    } | tee /tmp/gtmetrix-summary.log
  else
    {
    result_state=$(curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.state'| sed -e 's|\"||g')
    if [[ "$result_state" = 'completed' ]]; then
      curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.'
    else
      sleep 15s
      curl -4s --user $GTEMAIL:$GTAPIKEY $gtmetrix_result | jq '.'
    fi
    } > /tmp/gtmetrix-summary.log
  fi
  # waterfall=$(curl -4s --user $gtemail:$gtapikey ${gtmetrix_result}/har | jq)
  
  onload_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.onload_time')
  first_contentful_paint_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.first_contentful_paint_time')
  page_elements=$(cat /tmp/gtmetrix-summary.log | jq '.results.page_elements')
  report_url=$(cat /tmp/gtmetrix-summary.log | jq '.results.report_url'| sed -e 's|\"||g')
  redirect_duration=$(cat /tmp/gtmetrix-summary.log | jq '.results.redirect_duration')
  first_paint_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.first_paint_time')
  dom_content_loaded_duration=$(cat /tmp/gtmetrix-summary.log | jq '.results.dom_content_loaded_duration')
  dom_content_loaded_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.dom_content_loaded_time')
  dom_interactive_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.dom_interactive_time')
  page_bytes=$(cat /tmp/gtmetrix-summary.log | jq '.results.page_bytes')
  page_load_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.page_load_time')
  html_bytes=$(cat /tmp/gtmetrix-summary.log | jq '.results.html_bytes')
  fully_loaded_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.fully_loaded_time')
  html_load_time=$(cat /tmp/gtmetrix-summary.log | jq '.results.html_load_time')
  rum_speed_index=$(cat /tmp/gtmetrix-summary.log | jq '.results.rum_speed_index')
  yslow_score=$(cat /tmp/gtmetrix-summary.log | jq '.results.yslow_score')
  pagespeed_score=$(cat /tmp/gtmetrix-summary.log | jq '.results.pagespeed_score')
  backend_duration=$(cat /tmp/gtmetrix-summary.log | jq '.results.backend_duration')
  onload_duration=$(cat /tmp/gtmetrix-summary.log | jq '.results.onload_duration')
  connect_duration=$(cat /tmp/gtmetrix-summary.log | jq '.results.connect_duration')

  echo
  echo "--------------------------------------------------------------------------------"
  echo "GTMetrix Test (Dallas Chrome Broadband 5Mbps): ${prefix}://${domain}" | tee /tmp/gitool-gtmetrix-slack-summary.log
  echo "PageSpeed Score: $pagespeed_score YSlow Score: $yslow_score" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "Report: $report_url" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "Fully Loaded Time: $fully_loaded_time ms Total Page Size: $page_bytes (bytes) Requests: $page_elements" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "RUM Speed Index: $rum_speed_index" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "Redirect: $redirect_duration ms Connect: $connect_duration ms Backend: $backend_duration ms" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "TTFB: $html_load_time ms DOM-int: $dom_interactive_time ms First-paint: $first_paint_time ms" | tee -a /tmp/gitool-gtmetrix-slack-summary.log
  echo "Contentful-paint: $first_contentful_paint_time ms DOM-loaded: $dom_content_loaded_time ms Onload: $onload_time ms" | tee -a /tmp/gitool-gtmetrix-slack-summary.log

  if [[ "$SLACK" = [yY] ]]; then
    if [[ "$pagespeed_score" ]]; then
      send_message="$(cat /tmp/gitool-gtmetrix-slack-summary.log)"
      slacksend "$send_message" "$DT - GTMetrix"
    fi
  fi

  rm -rf /tmp/gtmetrix.log
  rm -rf /tmp/gtmetrix-summary.log
  rm -rf /tmp/gitool-gtmetrix-slack-summary.log
}

gi_run() {
  strategy=$3
  fulldomain=$1
  origin_check=$2
  prefix=$(echo $fulldomain | awk -F '://' '{print $1}')
  domain=$(echo $fulldomain | awk -F '://' '{print $2}')
  if [[ "$origin_check" = 'origin' ]]; then
    origins='origin%3A'
  elif [[ "$origin_check" = 'site' ]]; then
    origins='site%3A'
  elif [[ "$origin_check" = 'default' ]]; then
    origins='default'
  else
    origins='default site%3A origin%3A'
  fi
  for o in $origins; do
    if [[ "$o" = 'default' ]]; then
      o=""
      metric_opt='&fields=formattedResults%2CloadingExperience(initial_url%2Cmetrics%2Coverall_category)%2CpageStats%2CruleGroups'
    elif [[ "$o" = 'site%3A' ]]; then
      metric_opt='&fields=loadingExperience(initial_url%2Cmetrics%2Coverall_category)'
    elif [[ "$o" = 'origin%3A' ]]; then
      metric_opt='&fields=loadingExperience(initial_url%2Cmetrics%2Coverall_category)'
    fi
    turl_echo="https://www.googleapis.com/pagespeedonline/v4/runPagespeed?url=${o}${prefix}%3A%2F%2F${domain}%2F&screenshot=${screenshot_state}&snapshots=${snapshots_state}&strategy=${strategy}${metric_opt}&key=YOUR_GOOGLE_API_KEY"
    turl="https://www.googleapis.com/pagespeedonline/v4/runPagespeed?url=${o}${prefix}%3A%2F%2F${domain}%2F&screenshot=${screenshot_state}&snapshots=${snapshots_state}&strategy=${strategy}${metric_opt}&key=${GOOGLE_API_KEY}"
    echo
    echo "--------------------------------------------------------------------------------"
    if [[ "$CMD_OUTPUT" = [yY] ]]; then
      echo "curl -4s $turl_echo"
    fi
    if [[ "$JSON_OUTPUT" = [yY] ]]; then
      curl -4s $turl | tee /tmp/gitool-${strategy}.log
    else
      curl -4s $turl > /tmp/gitool-${strategy}.log
    fi
    err=$?
    if [[ "$err" -ne '0' || "$(wc -l < /tmp/gitool-${strategy}.log)" -lt '2' ]]; then
      echo
      echo "error: aborting..."
      exit
    fi

    # echo
    fcp_median=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.median")
    fcp_cat=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.category" | sed -e 's|\"||g')
    dcl_median=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.median")
    dcl_cat=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.category" | sed -e 's|\"||g')
    fcl_distribution_min=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.distributions" | jq '.[1] | .min')
    fcl_distribution_max=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.distributions" | jq '.[1] | .max')
    fcl_distribution_proportiona=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.distributions" | jq '.[0] | .proportion')
    fcl_distribution_proportionb=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.distributions" | jq '.[1] | .proportion')
    fcl_distribution_proportionc=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.distributions" | jq '.[2] | .proportion')
    if [[ "$fcp_median" != 'null' ]]; then
      fcl_distribution_proportiona_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $fcl_distribution_proportiona)*100" | bc))
      fcl_distribution_proportionb_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $fcl_distribution_proportionb)*100" | bc))
      fcl_distribution_proportionc_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $fcl_distribution_proportionc)*100" | bc))
    fi
    dcl_distribution_min=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.distributions" | jq '.[1] | .min')
    dcl_distribution_max=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.distributions" | jq '.[1] | .max')
    dcl_distribution_proportiona=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.distributions" | jq '.[0] | .proportion')
    dcl_distribution_proportionb=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.distributions" | jq '.[1] | .proportion')
    dcl_distribution_proportionc=$(cat /tmp/gitool-${strategy}.log | jq ".loadingExperience.metrics.DOM_CONTENT_LOADED_EVENT_FIRED_MS.distributions" | jq '.[2] | .proportion')
    if [[ "$dcl_median" != 'null' ]]; then
      dcl_distribution_proportiona_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $dcl_distribution_proportiona)*100" | bc))
      dcl_distribution_proportionb_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $dcl_distribution_proportionb)*100" | bc))
      dcl_distribution_proportionc_perc=$(printf "%.2f\n" $(echo "$(printf "%.3f\n" $dcl_distribution_proportionc)*100" | bc))
    fi
    if [[ "$fcp_median" != 'null' || "$dcl_median" != 'null' ]]; then
      echo "${prefix}://$domain FCP median: $fcp_median ($fcp_cat) ms DCL median: $dcl_median ms ($dcl_cat)" | tee /tmp/gitool-${strategy}-summary.log
      echo "Page Load Distributions" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$fcl_distribution_proportiona_perc % loads for this page have a fast FCP (less than $fcl_distribution_min milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$fcl_distribution_proportionb_perc % loads for this page have an average FCP (less than $fcl_distribution_max milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$fcl_distribution_proportionc_perc % loads for this page have a slow FCP (over $fcl_distribution_max milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$dcl_distribution_proportiona_perc % loads for this page have a fast DCL (less than $dcl_distribution_min milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$dcl_distribution_proportionb_perc % loads for this page have an average DCL (less than $dcl_distribution_max milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
      echo "$dcl_distribution_proportionc_perc % loads for this page have a slow DCL (over $dcl_distribution_max milliseconds)" | tee -a /tmp/gitool-${strategy}-summary.log
    fi
    echo
    if [[ "$SLACK" = [yY] ]]; then
      if [[ "$fcp_median" != 'null' || "$dcl_median" != 'null' ]]; then
        send_message="$(cat /tmp/gitool-${strategy}-summary.log)"
        slacksend "${strategy}\n$send_message" "$DT - Google PageSpeed Insights"
      fi
    fi
    rm -rf /tmp/gitool-${strategy}.log
    rm -rf /tmp/gitool-${strategy}-summary.log
  done
}

#########################################################
case $1 in
  desktop )
    gi_run $2 $3 desktop
    ;;
  mobile )
    gi_run $2 $3 mobile
    ;;
  all )
    gi_run $2 $3 desktop
    gi_run $2 $3 mobile
    ;;
  gtmetrix )
    if [[ "$GTMETRIX" = [yY] ]]; then
      gt_run $2 $3
    else
      echo "GTMETRIX='n' detected"
    fi
    ;;
  wpt )
    if [[ "$WPT" = [yY] ]]; then
      wpt_run $2 $3 $4 $5 $6
    else
      echo "WPT='n' detected"
    fi
    ;;
  * )
  echo
  echo "Usage:"
  echo
  echo "$0 desktop https://domain.com {default|origin|site}"
  echo "$0 mobile https://domain.com {default|origin|site}"
  echo "$0 all https://domain.com {default|origin|site}"
  echo
    ;;
esac
exit