CC = gcc
ASM = nasm
LD = ld

CC_FLAGS = -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c
LD_FLAGS = -nostdlib

FREE_LOOP = $(notdir $(shell sudo losetup -f))
MONOX_IMG = monox.img

BOOT_BIN = boot/boot.bin
LOADER_BIN = boot/loader.bin
KERNEL_BIN = kernel/kernel.bin
SHELL_BIN = shell/shell.bin
LIB_A = lib/lib.a

TOTALMEM = programs/totalmem/totalmem

KERNEL_HEADERS = kernel/debug.h kernel/file.h kernel/keyboard.h kernel/lib.h kernel/memory.h kernel/print.h kernel/process.h kernel/syscall.h kernel/trap.h
LOADER_HEADERS = boot/debug.h boot/file.h boot/lib.h boot/print.h
LIB_HEADERS = lib/lib.h

KERNEL_OBJECTS = kernel/kernel.out kernel/main.o kernel/trap.out kernel/trap.o kernel/lib.out kernel/print.o kernel/debug.o kernel/memory.o kernel/process.o kernel/syscall.o kernel/lib.o kernel/keyboard.o kernel/file.o
LOADER_OBJECTS = boot/entry.out boot/lib.out boot/debug.o boot/file.o boot/main.o boot/print.o
LIB_OBJECTS = lib/print.o lib/syscall.out lib/lib.out
SHELL_OBJECTS = shell/start.out shell/main.o shell/print.o
TOTALMEM_OBJECTS = programs/totalmem/start.out programs/totalmem/main.o

all: $(MONOX_IMG)
	bochs -q

clean:
	find . -name "*.o" -type f -delete
	find . -name "*.a" -type f -delete
	find . -name "*.bin" -type f -delete
	find . -name "*.elf" -type f -delete
	find . -name "*.img" -type f -delete
	find . -name "*.out" -type f -delete
	find . -wholename "$(TOTALMEM)" -type f -delete

$(MONOX_IMG): $(KERNEL_BIN) $(BOOT_BIN) $(LOADER_BIN) $(SHELL_BIN) $(TOTALMEM)
	dd if=/dev/zero of=boot.img bs=512 count=204624
	dd if=$(BOOT_BIN) of=boot.img bs=512 count=1 conv=notrunc
	dd if=$(LOADER_BIN) of=boot.img bs=512 seek=1 count=15 conv=notrunc
	sudo losetup /dev/$(FREE_LOOP) boot.img
	sudo kpartx -av /dev/$(FREE_LOOP)
	sudo mkfs.vfat -F 16 -R 16 -n "Monox" /dev/mapper/$(FREE_LOOP)p1
	mkdir os
	sudo mount /dev/mapper/$(FREE_LOOP)p1 os
	sudo cp $(KERNEL_BIN) os/kernel.bin
	sudo cp $(SHELL_BIN) os/shell.bin
	sudo cp $(TOTALMEM) os/totalmem
	sudo umount /dev/mapper/$(FREE_LOOP)p1
	sudo kpartx -dv /dev/$(FREE_LOOP)
	cp boot.img $(MONOX_IMG)
	rm -r os boot.img

$(KERNEL_BIN): $(KERNEL_OBJECTS)
	$(LD) $(LD_FLAGS) -T kernel/link.lds -o kernel/kernel.elf $^
	objcopy -O binary kernel/kernel.elf $(KERNEL_BIN)

$(LOADER_BIN): $(LOADER_OBJECTS) boot/loader.asm
	$(LD) $(LD_FLAGS) -T boot/link.lds -o boot/entry.elf $(LOADER_OBJECTS)
	objcopy -O binary boot/entry.elf boot/entry.bin
	$(ASM) -f bin -o $(LOADER_BIN) boot/loader.asm
	dd if=boot/entry.bin >> $(LOADER_BIN)

$(LIB_A): $(LIB_OBJECTS)
	ar rcs $(LIB_A) $(LIB_OBJECTS)

$(SHELL_BIN): $(SHELL_OBJECTS) $(LIB_A)
	$(LD) $(LDFLAGS) -T shell/link.lds -o shell/shell.elf $(SHELL_OBJECTS) $(LIB_A)
	objcopy -O binary shell/shell.elf $(SHELL_BIN)

$(TOTALMEM): $(TOTALMEM_OBJECTS) $(LIB_A) 
	$(LD) $(LDFLAGS) -T programs/totalmem/link.lds -o programs/totalmem/totalmem.elf $(TOTALMEM_OBJECTS) $(LIB_A)
	objcopy -O binary programs/totalmem/totalmem.elf $(TOTALMEM)

$(BOOT_BIN): boot/boot.asm
	$(ASM) -f bin -o $@ $<

%.out: %.asm
	$(ASM) -f elf64 -o $@ $<

%.o: %.c $(KERNEL_HEADERS) $(LOADER_HEADERS) $(LIB_HEADERS) $(SHELL_HEADERS)
	$(CC) $(CC_FLAGS) -o $@ $<
