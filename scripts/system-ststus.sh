dte(){
    echo -n "$(date +"%A, %B %d")"
}

tme(){
    echo -n "$(date +"%l:%M%p")"
}

upd(){
    echo -n `pacman -Qu | wc -l`
}

mem(){
    echo -n `free | awk '/Mem/ {printf " %d/%d MiB\n", $3 / 1024.0, $2 / 1024.0 }'`
}

cpu(){
    read cpu a b c previdle rest < /proc/stat
    prevtotal=$((a+b+c+previdle))
    sleep 0.5
    read cpu a b c idle rest < /proc/stat
    total=$((a+b+c+idle))
    cpu=$((100*( (total-prevtotal) - (idle-previdle) ) / (total-prevtotal) ))
    echo -e $cpu% cpu
}

vol(){
    echo -n `/home/jotix/.scripts/volctl -v`
}

disk(){
    echo -n `df -H / | grep -vE '^Filesystem|devtmpfs|tmpfs|esdamlinux|ccbtestnfs1' | awk '{ print $5 " " $1 }'`
}


echo "$(vol) | $(cpu) | $(mem) | $(disk) | $(dte) - $(tme)"   
