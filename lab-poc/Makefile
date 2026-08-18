CC     = gcc
CFLAGS = -Wall

.PHONY: all clean

all: pwnkit

pwnkit: pwnkit.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f pwnkit
	rm -rf 'GCONV_PATH=.' pwnkit
