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
	.text
	.p2align 4
	.globl	insertionsort
	.type	insertionsort, @function
insertionsort:
.LFB0:
	.cfi_startproc
	endbr64
	leaq	8(%rdi), %r11
	movl	$1, %r10d
	cmpq	$1, %rsi
	jbe	.L1
	.p2align 4,,10
	.p2align 3
.L6:
	movq	(%r11), %r9
	movq	%r11, %rax
	movq	%r10, %rdx
	jmp	.L3
	.p2align 4,,10
	.p2align 3
.L5:
	movq	%rcx, (%rax)
	leaq	-8(%r8), %rax
	subq	$1, %rdx
	je	.L8
.L3:
	movq	-8(%rax), %rcx
	movq	%rax, %r8
	cmpq	%r9, %rcx
	jg	.L5
	addq	$1, %r10
	movq	%r9, (%r8)
	addq	$8, %r11
	cmpq	%r10, %rsi
	jne	.L6
.L1:
	ret
	.p2align 4,,10
	.p2align 3
.L8:
	movq	%rdi, %r8
	addq	$1, %r10
	addq	$8, %r11
	movq	%r9, (%r8)
	cmpq	%r10, %rsi
	jne	.L6
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
