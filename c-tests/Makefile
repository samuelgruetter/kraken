CC     = gcc
CFLAGS = -O2 -ffreestanding -nostdlib -nostartfiles -fno-stack-protector -fno-pie -fno-pic -m64 -fverbose-asm
SRCS   = insertionsort.c insertionsort_tests.c
OBJS   = insertionsort.o insertionsort_tests.o
ASM    = insertionsort.s insertionsort_tests.s

.PHONY: all test clean

all: $(ASM) insertionsort_tests.exe

%.s: %.c
	$(CC) $(CFLAGS) -S -o $@ $<

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

insertionsort_tests.exe: $(OBJS)
	ld -o $@ $(OBJS)

test: insertionsort_tests.exe
	./insertionsort_tests.exe > /tmp/isort_actual.bin
	python3 -c "import struct, sys; sys.stdout.buffer.write(struct.pack('<5q', -1000000000000, -5, 42, 42, 1000000000000))" > /tmp/isort_expected.bin
	cmp /tmp/isort_actual.bin /tmp/isort_expected.bin && echo "PASS" || (echo "FAIL"; exit 1)

clean:
	rm -f $(OBJS) $(ASM) insertionsort_tests.exe *_instrumented.s /tmp/isort_actual.bin /tmp/isort_expected.bin
