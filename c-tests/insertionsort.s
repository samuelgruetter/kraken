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
