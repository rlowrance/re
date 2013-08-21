# set-lua-path.sh
# set the lua path on $ACCESS

KS="/home/roy/kernel-smoothers"

export LUA_PATH=";$KS;$KS/?.lua"
echo LUA_PATH is $LUA_PATH
