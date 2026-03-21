	.file	"insertionsort_tests.c"
	.text
	.p2align 4
	.globl	_start
	.type	_start, @function
_start:
.LFB2:
	.cfi_startproc
	endbr64
	pushq	%rax
	.cfi_def_cfa_offset 16
	popq	%rax
	.cfi_def_cfa_offset 8
	movl	$5, %esi
	movl	$test_array, %edi
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	call	insertionsort
	movl	$1, %eax
	movl	$test_array, %esi
	movl	$40, %edx
	movq	%rax, %rdi
#APP
# 9 "insertionsort_tests.c" 1
	syscall
# 0 "" 2
#NO_APP
	movl	$60, %eax
	xorl	%edi, %edi
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
