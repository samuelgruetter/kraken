	.file	"insertionsort_tests.c"
# GNU C17 (Ubuntu 13.3.0-6ubuntu2~24.04.1) version 13.3.0 (x86_64-linux-gnu)
#	compiled by GNU C version 13.3.0, GMP version 6.3.0, MPFR version 4.2.1, MPC version 1.3.1, isl version isl-0.26-GMP

# GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072
# options passed: -m64 -mtune=generic -march=x86-64 -O2 -ffreestanding -fno-stack-protector -fno-pic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection
	.text
	.p2align 4
	.globl	_start
	.type	_start, @function
_start:
.LFB2:
	.cfi_startproc
	endbr64	
	pushq	%rax	#
	.cfi_def_cfa_offset 16
	popq	%rax	#
	.cfi_def_cfa_offset 8
# insertionsort_tests.c:28:     insertionsort(test_array, 5);
	movl	$5, %esi	#,
	movl	$test_array, %edi	#,
# insertionsort_tests.c:27: void _start(void) {
	subq	$8, %rsp	#,
	.cfi_def_cfa_offset 16
# insertionsort_tests.c:28:     insertionsort(test_array, 5);
	call	insertionsort	#
# insertionsort_tests.c:9:     __asm__ volatile (
	movl	$1, %eax	#, tmp82
	movl	$test_array, %esi	#, tmp84
	movl	$40, %edx	#, tmp85
	movq	%rax, %rdi	# tmp82, tmp82
#APP
# 9 "insertionsort_tests.c" 1
	syscall	
# 0 "" 2
# insertionsort_tests.c:18:     __asm__ volatile (
#NO_APP
	movl	$60, %eax	#, tmp86
	xorl	%edi, %edi	# tmp87
#APP
# 18 "insertionsort_tests.c" 1
	syscall	
# 0 "" 2
#NO_APP
	.cfi_endproc
.LFE2:
	.size	_start, .-_start
	.globl	test_array
	.data
	.align 32
	.type	test_array, @object
	.size	test_array, 40
test_array:
	.quad	1000000000000
	.quad	-5
	.quad	42
	.quad	42
	.quad	-1000000000000
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
