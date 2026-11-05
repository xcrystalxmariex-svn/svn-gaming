"""svn-gaming KVM probe: tells you whether this host can run dockur/windows (Windows in a container via KVM).
Serves a plain-text report on $PORT (default 8000). Stdlib only."""
import os
import platform
from http.server import BaseHTTPRequestHandler, HTTPServer


def read(path, default="n/a"):
    try:
        with open(path) as f:
            return f.read()
    except Exception as e:
        return f"{default} ({e.__class__.__name__})"


def report():
    lines = []
    kvm = os.path.exists("/dev/kvm")
    kvm_rw = kvm and os.access("/dev/kvm", os.R_OK | os.W_OK)
    cpuinfo = read("/proc/cpuinfo", "")
    flags = set()
    model = "unknown"
    for line in cpuinfo.splitlines():
        if line.startswith("flags") and not flags:
            flags = set(line.split(":", 1)[1].split())
        if line.startswith("model name") and model == "unknown":
            model = line.split(":", 1)[1].strip()
    virt = "vmx (Intel VT-x)" if "vmx" in flags else "svm (AMD-V)" if "svm" in flags else "none"

    status = read("/proc/self/status", "")
    capeff = next((l.split()[1] for l in status.splitlines() if l.startswith("CapEff")), "n/a")
    privileged = capeff.lower().endswith("ffffffffff")

    mem_limit = read("/sys/fs/cgroup/memory.max").strip()
    if mem_limit.startswith("n/a"):
        mem_limit = read("/sys/fs/cgroup/memory/memory.limit_in_bytes").strip()
    cpu_max = read("/sys/fs/cgroup/cpu.max").strip()

    verdict = "YES: dockur/windows can use KVM here" if kvm_rw and virt != "none" else (
        "PARTIAL: /dev/kvm exists but this container can't open it (needs --device /dev/kvm or privileged)" if kvm else
        "NO: no /dev/kvm. dockur/windows would fall back to pure emulation (far too slow for a game)")

    lines += [
        "== svn-gaming KVM probe ==",
        f"VERDICT: {verdict}",
        "",
        f"/dev/kvm present:      {kvm}",
        f"/dev/kvm read/write:   {kvm_rw}",
        f"CPU virt extensions:   {virt}",
        f"CPU model:             {model}",
        f"Arch:                  {platform.machine()}",
        f"Kernel:                {platform.release()}",
        f"CPUs visible:          {os.cpu_count()}",
        f"cgroup cpu.max:        {cpu_max}",
        f"cgroup memory limit:   {mem_limit}",
        f"Running as root:       {os.geteuid() == 0}",
        f"CapEff:                {capeff} (privileged-looking: {privileged})",
        f"/dev entries:          {', '.join(sorted(os.listdir('/dev'))[:60])}",
        "",
        "MemTotal/MemAvailable:",
        "\n".join(l for l in read("/proc/meminfo", "").splitlines() if l.startswith(("MemTotal", "MemAvailable"))),
    ]
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = report().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    print(report(), flush=True)
    print(f"Serving probe on 0.0.0.0:{port}", flush=True)
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
