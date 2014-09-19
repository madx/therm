RELEASE?=0

VALAC=valac
VALA_FLAGS=--pkg vte-2.90 --pkg gtk+-3.0 --pkg gdk-3.0 --fatal-warnings
ifeq ($(RELEASE), 1)
	VALA_FLAGS+=-X -O2
endif

all: therm

% : src/%.vala
	$(VALAC) $(VALA_FLAGS) $^

%.c : src/%.vala
	$(VALAC) -C $(VALA_FLAGS) $^

clean:
	rm -f therm schemas/gschemas.compiled
	rm -rf glib-2.0

install-local-schemas: glib-2.0/schemas/gschemas.compiled
glib-2.0/schemas/gschemas.compiled: schemas/org.yapok.therm.gschema.xml
	mkdir -p glib-2.0/schemas schemas
	glib-compile-schemas --targetdir=glib-2.0/schemas schemas

run-local: therm install-local-schemas
	XDG_DATA_DIRS="$(shell pwd):${XDG_DATA_DIRS}" ./therm

.PHONY: all clean run-local install-local-schemas
