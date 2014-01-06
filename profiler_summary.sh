# summarize luaprofiler results
SCRIPT=/usr/local/lib/luarocks/rocks/luaprofiler/2.0.2-2/bin/summary.lua
DATA=/tmp/luaprofiler.txt
# parameters -v makes results verbose
lua $SCRIPT -v $DATA > luaprofiler_summary_verbose.txt
lua $SCRIPT $DATA > luaprofiler_summary.txt

