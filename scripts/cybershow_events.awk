BEGIN { COOLDOWN = 2 }

function base_domain(d,    n, a, x) {
    x = tolower(d)
    sub(/\.$/, "", x)
    n = split(x, a, ".")
    if (n >= 2) return a[n-1] "." a[n]
    return x
}

function is_noise(d) {
    if (d ~ /\.arpa$/ || d ~ /\.local$/) return 1
    if (d !~ /\./) return 1
    return 0
}

function esc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
}

/query\[A/ {
    dom = ""
    ip  = ""
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^query\[A/) dom = $(i + 1)
        if ($i == "from")     ip  = $(i + 1)
    }
    if (dom == "" || ip == "") next
    if (is_noise(dom)) next

    bd  = base_domain(dom)
    key = ip "|" bd
    now = systime()
    if ((key in last) && now - last[key] < COOLDOWN) next
    last[key] = now

    printf "{\"type\":\"traffic\",\"domain\":\"%s\",\"ip\":\"%s\",\"ts\":%d}\n", \
        esc(dom), esc(ip), now
    fflush()
}
