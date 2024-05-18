d=~/tmp/temporal/slack

# a thread is split across files
files-by-thread() {
    rg -r '$1' '.*"thread_ts": "(\d+\.\d+)".*' $d |
        sort -t: -k2 |
        rg -r '$2 $1' '([^:]+):(.+)'
}
