SRCS = $(wildcard *.vala)

all: rubik

rubik: $(SRCS)
	valac --vapidir . --pkg clutter-1.0 main.vala -g --save-temps -o rubik

run: rubik
	./rubik

run-gdb: rubik
	gdb --args ./rubik