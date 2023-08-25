.DEFAULT:

.PHONY: lint lint-fix test

lint:
	@shellcheck -x *.sh
	@shfmt -i 2 -ci -s -d .

lint-fix:
	@shfmt -i 2 -ci -s -w .

tests/node_modules/.bin/bats:
	@npm --prefix=tests ci

test: tests/node_modules/.bin/bats
	@tests/node_modules/.bin/bats --no-tempdir-cleanup --tap tests/search.bats

build:
	./build.sh $(word 2, $(MAKECMDGOALS))

%:
	@:
