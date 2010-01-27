#! /bin/bash

#(C) 2009 C. Junghans
# junghans@mpip-mainz.mpg.de

#version 0.1  22.12.09 -- initial version

usage="Usage: ${0##*/} quotefile"
quiet="no"
number=25
length=4
debug="no"
lpr="no"

die() {
  echo -e "$*"
  exit 1
}

qecho() {
  [ "$quiet" = "yes" ] || echo -e "$*"
}

show_help () {
  cat << eof
This is a skeleton script
$usage
OPTIONS:
-n NUMBER           Number of sheet to create
                    Default: $number
-l NUMBER           Length of the bingo
                    Default: $length
-q, --quiet         Be a little bit quiet
    --lpr           Print them later
    --debug         Enable debug
-h, --help          Show this help
-v, --version       Show version
    --hg            Show last log message for hg (or cvs)

Examples:  ${0##*/} -q
           ${0##*/}

Send bugs and comment to junghans@mpip-mainz.mpg.de
eof
}

while [ "${1#-}" != "$1" ]; do
 if [ "${1#--}" = "$1" ] && [ -n "${1:2}" ]; then
    #short opt with arguments here: fc
    if [ "${1#-[fc]}" != "${1}" ]; then
       set -- "${1:0:2}" "${1:2}" "${@:2}"
    else
       set -- "${1:0:2}" "-${1:2}" "${@:2}"
    fi
 fi
 case $1 in 
  --lpr)
    lpr="yes"
    shift ;;
  --debug)
    debug="yes"
    shift ;;
   -q | --quiet)
    quiet="yes"
    shift ;;
   -n)
    number="$2"
    shift 2;;
   -l)
    length="$2"
    shift 2;;
   -h | --help)
    show_help
    exit 0;;
   --hg)
    echo "${0##*/}: $(sed -ne 's/^#version.* -- \(.*$\)/\1/p' $0 | sed -n '$p')"
    exit 0;;
   -v | --version)
    echo "${0##*/}, $(sed -ne 's/^#\(version.*\) -- .*$/\1/p' $0 | sed -n '$p') by C. Junghans"
    exit 0;;
  *)
   die "Unknown option '$1'";;
 esac
done

[ -z "$1" ] && die "No quotefile given !\n$usage\nHelp with -h"
[ -f "$1" ] || die "quotefile not readable"

width="$(awk -v l=$length 'BEGIN{printf "%.1f",1/l}')"
for ((i=0;i<$number;i++)); do
  thisfile="$(printf 'bingo_%02i.tex' $((i+1)) )"
  [ -f "$thisfile" ] && die "$thisfile is already there"
  cat <<EOF >$thisfile
\documentclass[10pt,a4paper,onecolumn]{article}
\begin{document}
\pagestyle{empty}
\noindent
\begin{center}
{\huge MMM Bingo}\\\\
{\small \today}\\\\
\vspace{3cm}
EOF
  echo -n '\begin{tabular}{|c' >> $thisfile
  for ((j=0;j<$length;j++)); do
    echo -n "p{$width\\textwidth}|" >> $thisfile
  done
  echo "}" >> $thisfile
  echo '\hline' >> $thisfile
  sort -R $1 | head -$((length*length)) | sed \
    -e "1~${length}s/^/\\\\rule{0pt}{$width\\\\textwidth} \&\\n/" \
    -e 's/$/ \&/' \
    -e "${length}~${length}s/&$/\\\\\\\\ \\n\\\\hline/" \
    -e '$s/\\\\$//' >> $thisfile
  cat <<EOF >>$thisfile
\end{tabular}\\\\
\end{center}
\end{document}
EOF
  pdflatex $thisfile
  [ "$debug" = "yes" ] && cat ${thisfile}
  rm ${thisfile} ${thisfile%.tex}.log ${thisfile%.tex}.aux
  if [ "$lpr" = "yes" ]; then
    lpr ${thisfile%.tex}.pdf
    rm ${thisfile%.tex}.pdf
  fi
done
