ASM = ./Merlin32
CADIUS = ./cadius

all: diskimage

diskimage: hdtelnet.system
	$(CADIUS) REPLACEFILE hdtelnet.po /hdtelnet HDTELNET.SYSTEM#FF0000

hdtelnet.system: hdtelnet
	mv hdtelnet HDTELNET.SYSTEM#FF0000

hdtelnet:
	$(ASM) -v hdtelnet.s

clean:
	rm -f hdtelnet HDTELNET.SYSTEM#FF0000
