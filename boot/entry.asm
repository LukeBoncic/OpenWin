section .note.GNU-stack noalloc noexec nowrite progbits
section .text
extern main
global start

start:
	mov rsp,0xffff800000200000
	call main

	mov rax,0xffff800000200000
	jmp rax
	
End:
	hlt
	jmp End


