#!/bin/bash

################U#3#0#2#9#3#################
# REMOTE LOGIN SCRIPT / ENVIRONMENT ACCESS #
############################################

helpme () { 
  clear
  echo " ---------------------- "
  echo "    RLOGIN MENU HELP    "
  echo " ---------------------- "
  echo " This script will choose" 
  echo "  the best server match "
  echo "   based on your input. "
  echo " ---------------------- "
  echo "                        "
  echo " PILLAR : O / S / A / P "
  echo "                        "
  echo " ENVIR  : 1 / 2 / ...   "
  echo "                        "
  echo "   will result in an    "
  echo "   environment match    "
  echo " ---------------------- "
  echo "                        "
  echo " TYPE   : L / N / D / F "
  echo "                        "
  echo " L = Linux Master       "
  echo " N = Native application "
  echo " D = Database server    "
  echo " F = NFS fileserver     "
  echo "                        "
  echo " TYPENR : 1 / 2 / ...   "
  echo "                        "
  echo "   will result in a     "
  echo "   type server match    "
  echo " ---------------------- "
  echo "                        "
  echo "   SPECIAL COMMANDS     "
  echo "                        "
  echo " + switch ssh/xterm mode"
  echo " - show nfs/drp servers "
  echo " . shrink/expand (Xwin) "
  echo " H display this screen  "
  echo " Q quit                 "
  echo " ---------------------- "
  echo "                        "
  echo " Assumed input defaults "
  echo "                        "
  echo " PILLAR=O ENVIR=1 TYPE=L"    
  echo "                        "
  echo " ---------------------- "
  read stop
}

 choice=""
 nfs="off"
 exec="ssh"
 small="off"

 while [ "$choice" != "q" ]; do

 if [ "$1" = "" ]; then
    echo "-------------------------"
    echo "    $exec LOGIN menu     "
    echo "-------------------------"
    echo "       [ MX3Ox ]         " 
    echo " OxL0] MASTER 0 s28860pr "
    echo " OxN1] NATIVE 1 s28860ze "
    echo " OxN2] NATIVE 2 s28860zf "
    echo " OxD1] DATABASE s288607s "
    if [ "$nfs" = "on" ];then echo " OxF1] NFS ONT  s28860qi ";fi 
    echo "-------------------------"
    echo "       [ MX3S1 ]         " 
    echo " S1L0] MASTER 0 s28860ps "
    echo " S1N1] NATIVE 1 s28860xz "
    echo " S1N2] NATIVE 2 s28860y6 "
    echo " S1D1] DATABASE s288607t "
    if [ "$nfs" = "on" ];then echo " S1F1] NFS SINT s28860qi ";fi
    echo "-------------------------"
    echo "       [ MX3S2 ]         " 
    echo " S2L0] MASTER0  s28860z1 "
    echo " S2N1] NATIVE1  s28860zo "
    echo " S2D1] DATABASE s28860bi "
    echo "-------------------------"
    echo "       [ MX3A1 ]         " 
    echo " A1L0] MASTER 0 s1600021 "
    echo " A1N1] NATIVE 1 s16000gy "
    echo " A1N2] NATIVE 2 s16000gz "
    echo " A1N3] NATIVE 3 s16000h0 "
    echo " A1N4] NATIVE 4 s16000h1 "
    echo " A1D1] DATABASE s11067j3 "
    if [ "$nfs" = "on" ];then echo " A1F1] NFS ACC  s160004c ";fi
    echo "-------------------------"
    echo "       [ MX3A2 ]         " 
    echo " A2L0] MASTER 0 s16000fz "
    echo " A2N1] NATIVE 1 s16000hl "
    echo " A2D1] DATABASE s11067vw "
    echo "-------------------------"
    echo "       [ MX3P1 ]         " 
    echo " P1L0] MASTER 0 s08985to "
    echo " P1N1] NATIVE 1 s08986tt "
    echo " P1N2] NATIVE 2 s08986tc "
    echo " P1N3] NATIVE 3 s08986td "
    echo " P1N4] NATIVE 4 s08986tv "
    echo " P1N5] NATIVE 5 s08986ts "
    if [ "$drp" = "on" ];then echo " P1N6] NATIVE 6 s16000tm ";fi
    if [ "$drp" = "on" ];then echo " P1N7] NATIVE 7 s16000tn ";fi
    if [ "$drp" = "on" ];then echo " P1N8] NATIVE 8 s16000to ";fi
    echo " P1D1] DATABASE sa006594 "
    if [ "$nfs" = "on" ];then echo " P1F1] NFS PRO  s08985vg ";fi
    echo "-------------------------"
    echo "       [ MX3P2 ]         " 
    echo " P2L0] MASTER 0 s08986su "
    echo " P2N1] NATIVE 1 s08986tu "
    echo " P2N2] NATIVE 2 s08986v6 "
    echo "-------------------------"
    echo " q) quit        h) help "
    echo 
    printf " Enter choice: [    ]\b\b\b\b\b"
    read choice
  else 
    choice=$1
    shift $#
  fi

  strindex() { 
     x="${1%%$2*}"
    [[ $x = $1 ]] && echo -1 || echo ${#x};
  }
  choice=`echo $choice | tr "[:lower:]" "[:upper:]"`

# BEGIN PARSING INPUT TO GO TO CORRECT ENVIRONMENT

env="";type="";envnr="";typenr="";
if [ -n "$choice" ]; then
  case $choice in
    *"O"*) env="O";e="$(strindex "$choice" "O" )";;
    *"S"*) env="S";e="$(strindex "$choice" "S" )";;
    *"A"*) env="A";e="$(strindex "$choice" "A" )";;
    *"P"*) env="P";e="$(strindex "$choice" "P" )";;
    *"Q"*) exit 0;;
  esac

  case $choice in
    *"L"*) type="L";t="$(strindex "$choice" "L" )";ltype="MASTER";; 
    *"N"*) type="N";t="$(strindex "$choice" "N" )";ltype="NATIVE";;
    *"D"*) type="D";t="$(strindex "$choice" "D" )";ltype="DATABASE";;
    *"F"*) type="F";t="$(strindex "$choice" "F" )";ltype="NFS FILESYSTEM";;
     "H" ) helpme;;
     "-" ) case $nfs in
             "on"  ) nfs="off";drp="off";;
             "off" ) nfs="on";drp="on";;
           esac;;
     "+" ) case $exec in
             "ssh"   ) exec="xterm";;
             "xterm" ) exec="ssh";; 
           esac;;
     "." ) case $small in
             "off" ) printf '\033[8;50;20t';small="on";;
             *     ) printf '\033[8;50;132t';small="off";; 
           esac;;           
  esac

  if [ -n "$env" ];  then 
     envnr=${choice:$e+1:2};
     if ! [[ "$envnr"  =~ ^[0-9]+$ ]]; then envnr=${choice:$e+1:1};fi
  fi 
  if [ -n "$type" ]; then typenr=${choice:$t+1:1};fi

#  echo [$env][$envnr][$type][$typenr]

  if  [ -z "$env" ] && [ -z "$type" ]; then
      printf ""
  else
      if   [[ "$env"    == ""       ]]; then env="O"; fi
      if ! [[ "$envnr"  =~ ^[0-9]+$ ]]; then envnr=1; fi
      if   [[ "$type"   == ""       ]]; then type="L"; fi
      if ! [[ "$typenr" =~ ^[0-9]+$ ]]; then 
                 if [ "$type" == "L" ]; then typenr=0;
                                        else typenr=1;
                 fi
      fi
  fi
fi

mxenv="MX3$env$envnr"

case $env in
    "O") bg="DarkSlateGrey";;  
    "S") bg="Black";;
    "A") bg="DodgerBlue4";;
    "P") bg="MidnightBlue";;
esac

case $type in
  "L") ltype="MASTER";mxusr="murex$envnr";fg="Yellow";; 
  "N") ltype="NATIVE $envnr";mxusr="murex$envnr";fg="Yellow";;
  "D") ltype="DATABASE";mxusr="murex1";fg="Yellow";;
  "F") ltype="NFS FILESYSTEM";mxusr="murex1";fg="Yellow";;
esac

# END PARSING INPUT

  choice="$env$envnr$type$typenr"

  echo
 
    case $choice in
      O*L0 ) server=s28860pr.servers.kbct.be;;
      O*N1 ) server=s28860ze.servers.kbct.be;; 
      O*N2 ) server=s28860zf.servers.kbct.be;;
      O*D1 ) server=s288607s.servers.kbct.be;;
      O*F1 ) server=s28860qi.be.srv.dev.sys ;;

      S1L0 ) server=s28860ps.servers.kbct.be;;
      S1N1 ) server=s28860xz.servers.kbct.be;;    
      S1N2 ) server=s28860y6.servers.kbct.be;;    
      S1D1 ) server=s288607t.servers.kbct.be;;
      S1F1 ) server=s28860qi.be.srv.dev.sys ;;

      S2L0 ) server=s28860z1.servers.kbct.be;;
      S2N1 ) server=s28860zo.servers.kbct.be;;    
      S2D1 ) server=s28860bi.servers.kbct.be;;

      A1L0 ) server=s1600021.servers.kbca.be;;
      A1N1 ) server=s16000gy.servers.kbca.be;;    
      A1N2 ) server=s16000gz.servers.kbca.be;;    
      A1N3 ) server=s16000h0.servers.kbca.be;;    
      A1N4 ) server=s16000h1.servers.kbca.be;;    
      A1N5 ) server=s1002560.servers.kbca.be;;    
      A1N6 ) server=s1007640.servers.kbca.be;;    
      A1D1 ) server=s11067j3.servers.kbca.be;;
      A1F1 ) server=s160004c.be.srv.acc.sys ;;

      A2L0 ) server=s16000fz.servers.kbca.be;;
      A2N1 ) server=s16000hl.servers.kbca.be;;
      A2D1 ) server=s11067vw.servers.kbca.be;;

      P1L0 ) server=s08985to.servers.kbc.be ;; 
      P1N1 ) server=s08986tt.servers.kbc.be ;; 
      P1N2 ) server=s08986tc.servers.kbc.be ;;
      P1N3 ) server=s08986td.servers.kbc.be ;;
      P1N4 ) server=s08986tv.servers.kbc.be ;;
      P1N5 ) server=s08986ts.servers.kbc.be ;;
      P1N6 ) server=s08986tm.servers.kbc.be ;;
      P1N7 ) server=s08986tn.servers.kbc.be ;;
      P1N8 ) server=s08986to.servers.kbc.be ;;
      P1D1 ) server=sa006594.servers.kbc.be ;;
      P1F1 ) server=s08985vg.be.srv.sys     ;;

      P2L0 ) server=s08986su.servers.kbc.be ;; 
      P2N1 ) server=s08986tu.servers.kbc.be ;; 
      P2N2 ) server=s08986v6.servers.kbc.be ;;
# --------------------------------------------------------
      *  ) echo " No server match [$choice]"; server="";;
    esac

    if [ -n "$server" ]; then
       color='\033[01;37m'
       nocolor='\033[0m' 
       conmsg="Connecting to [$mxenv] $ltype with $mxusr"
       colorconmsg="${color}${conmsg}${nocolor}"
       if [ "$exec" = "ssh" ]; then
          printf '\033[8;50;132';sleep 1;
          echo -e $colorconmsg
          ssh $server -l $mxusr -q;
          # restore terminal title set by .userprofile
          echo -ne "\033]0;$TERM_TITLE\007"
          exit 0;
       else
          xterm -rightbar -bg $bg -fg $fg -geometry 132x40+200+0 -sl 2000 -e /bin/bash -l -c "clear;echo $conmsg;ssh $server -l $mxusr -q;" &
       fi
    fi
 done

