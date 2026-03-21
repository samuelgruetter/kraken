.data
.align 8
# Final register state (filled by capture epilogue)
_kraken_final_rax: .quad 0
_kraken_final_rbx: .quad 0
_kraken_final_rcx: .quad 0
_kraken_final_rdx: .quad 0
_kraken_final_rsi: .quad 0
_kraken_final_rdi: .quad 0
_kraken_final_rsp: .quad 0
_kraken_final_rbp: .quad 0
_kraken_final_r8: .quad 0
_kraken_final_r9: .quad 0
_kraken_final_r10: .quad 0
_kraken_final_r11: .quad 0
_kraken_final_r12: .quad 0
_kraken_final_r13: .quad 0
_kraken_final_r14: .quad 0
_kraken_final_r15: .quad 0
_kraken_final_flags: .quad 0

# Memory regions to track
_kraken_mem_region_count: .quad 1
# Memory region 0: test_array (5 int64_t values)
_kraken_mem_region_0_base: .quad test_array
_kraken_mem_region_0_size: .quad 5
_kraken_mem_region_0_data: .space 40
	.file	"insertionsort.c"
# GNU C17 (Ubuntu 13.3.0-6ubuntu2~24.04.1) version 13.3.0 (x86_64-linux-gnu)
#	compiled by GNU C version 13.3.0, GMP version 6.3.0, MPFR version 4.2.1, MPC version 1.3.1, isl version isl-0.26-GMP

# GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072
# options passed: -m64 -mtune=generic -march=x86-64 -O2 -ffreestanding -fno-stack-protector -fno-pic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection
	.text
	.p2align 4
	.globl	insertionsort
	.type	insertionsort, @function
insertionsort:
.LFB0:
	.cfi_startproc
	endbr64	
	leaq	8(%rdi), %r11	#, ivtmp.19
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	movl	$1, %r10d	#, i
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	cmpq	$1, %rsi	#, n
	jbe	.L1	#,
	.p2align 4,,10
	.p2align 3
.L6:
# insertionsort.c:6:         int64_t key = arr[i];
	movq	(%r11), %r9	# MEM[(int64_t *)_9], key
	movq	%r11, %rax	# ivtmp.19, ivtmp.10
# insertionsort.c:7:         size_t j = i;
	movq	%r10, %rdx	# i, j
	jmp	.L3	#
	.p2align 4,,10
	.p2align 3
.L5:
# insertionsort.c:9:             arr[j] = arr[j-1];
	movq	%rcx, (%rax)	# _8, MEM[(int64_t *)_12]
# insertionsort.c:8:         while (j > 0 && arr[j-1] > key) {
	leaq	-8(%r8), %rax	#, ivtmp.10
	subq	$1, %rdx	#, j
	je	.L8	#,
.L3:
# insertionsort.c:8:         while (j > 0 && arr[j-1] > key) {
	movq	-8(%rax), %rcx	# MEM[(int64_t *)_12 + -8B], _8
	movq	%rax, %r8	# ivtmp.10, _12
# insertionsort.c:8:         while (j > 0 && arr[j-1] > key) {
	cmpq	%r9, %rcx	# key, _8
	jg	.L5	#,
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	addq	$1, %r10	#, i
# insertionsort.c:12:         arr[j] = key;
	movq	%r9, (%r8)	# key, *prephitmp_37
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	addq	$8, %r11	#, ivtmp.19
	cmpq	%r10, %rsi	# i, n
	jne	.L6	#,
.L1:
# insertionsort.c:14: }
	ret	
	.p2align 4,,10
	.p2align 3
.L8:
	movq	%rdi, %r8	# arr, _12
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	addq	$1, %r10	#, i
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	addq	$8, %r11	#, ivtmp.19
# insertionsort.c:12:         arr[j] = key;
	movq	%r9, (%r8)	# key, *prephitmp_37
# insertionsort.c:5:     for (size_t i = 1; i < n; i++) {
	cmpq	%r10, %rsi	# i, n
	jne	.L6	#,
	ret	
	.cfi_endproc
.LFE0:
	.size	insertionsort, .-insertionsort
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:

.data
.globl test_array
.align 8
.type test_array, @object
.size test_array, 40
test_array:
    .quad 1000000000000
    .quad -5
    .quad 42
    .quad 42
    .quad -1000000000000

.text
.globl _start
.type _start, @function
_start:
    leaq test_array(%rip), %rdi
    movq $5, %rsi
    call insertionsort
    jmp _kraken_capture

# ====== KRAKEN CAPTURE EPILOGUE ======
_kraken_capture:
    # Save all registers to .data section
    movq %rax, _kraken_final_rax(%rip)
    movq %rbx, _kraken_final_rbx(%rip)
    movq %rcx, _kraken_final_rcx(%rip)
    movq %rdx, _kraken_final_rdx(%rip)
    movq %rsi, _kraken_final_rsi(%rip)
    movq %rdi, _kraken_final_rdi(%rip)
    movq %rsp, _kraken_final_rsp(%rip)
    movq %rbp, _kraken_final_rbp(%rip)
    movq %r8,  _kraken_final_r8(%rip)
    movq %r9,  _kraken_final_r9(%rip)
    movq %r10, _kraken_final_r10(%rip)
    movq %r11, _kraken_final_r11(%rip)
    movq %r12, _kraken_final_r12(%rip)
    movq %r13, _kraken_final_r13(%rip)
    movq %r14, _kraken_final_r14(%rip)
    movq %r15, _kraken_final_r15(%rip)
    # Save flags
    pushfq
    popq %rax
    movq %rax, _kraken_final_flags(%rip)

    # Copy memory regions to dump buffers
    # Copy memory region 0
    movq _kraken_mem_region_0_base(%rip), %rsi  # source = base
    leaq _kraken_mem_region_0_data(%rip), %rdi  # dest = buffer
    movq $5, %rcx                  # count = size words
    rep movsq                             # copy

    # Write register state to stdout (136 bytes)
    movq $1, %rax         # sys_write
    movq $1, %rdi         # stdout
    leaq _kraken_final_rax(%rip), %rsi  # buffer start
    movq $136, %rdx       # 17 quads = 136 bytes
    syscall

    # Write memory region data to stdout
    movq $1, %rax
    movq $1, %rdi
    leaq _kraken_mem_region_count(%rip), %rsi
    movq $64, %rdx
    syscall

    # Exit with code 0
    movq $60, %rax
    xorq %rdi, %rdi
    syscall
