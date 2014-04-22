VALAC=valac
VALA_FLAGS=--pkg vte-2.90 --fatal-warnings

all: therm

% : src/%.vala
	$(VALAC) $(VALA_FLAGS) $^

%.c : src/%.vala
	$(VALAC) -C $(VALA_FLAGS) $^
