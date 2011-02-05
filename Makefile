SRCS = $(wildcard *.vala)

all: rubik

rubik: $(SRCS)
	valac --vapidir . --pkg clutter-1.0 --pkg json-glib-1.0 $(SRCS) -g --save-temps -o rubik

run: rubik
	./rubik

run-gdb: rubik
	gdb --args ./rubik

clean:
	rm -f $(subst .vala,.c,$(SRCS)) rubik
