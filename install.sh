# * * * * * "command to be executed"
# - - - - -
# | | | | |
# | | | | ----- Day of week (0 - 7) (Sunday=0 or 7)
# | | | ------- Month (1 - 12)
# | | --------- Day of month (1 - 31)
# | ----------- Hour (0 - 23)
# ------------- Minute (0 - 59)
croncmd="git --git-dir=$(dirname $(readlink -f $BASH_SOURCE))/.git pull";
cronjob="0 */15 * * * $croncmd";
( crontab -u $USER -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -u $USER -
