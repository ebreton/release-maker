#!make
# Default values, can be overridden either on the command line of make
# or in .env

.PHONY: version vars ps \
	build pull changelog \
	release push-qa push-prod

VERSION:=$(shell \
	docker run --rm -it \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		-v $(PWD)/versions.py:/usr/src/app/versions.py \
		python-requests update_release.py -v)

version:
	@echo CHANGELOG GENERATOR:
	@docker run -it --rm \
		-v "$(pwd)":/usr/local/src/your-app \
		ferrarimarco/github-changelog-generator \
		--version
	@echo ''
	@echo APPLICATION: 
	@echo Version: $(VERSION)
	@echo ''
	@echo Updating release numbers...
	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py

vars: check-env
	@echo '  Version: $(VERSION)'
	@echo ''
	@echo '  GITHUB_OWNER=${GITHUB_OWNER}'
	@echo '  GITHUB_REPO=${GITHUB_REPO}'
	@echo '  GITHUB_USER=${GITHUB_USER}'
	@echo '  GITHUB_TOKEN=${GITHUB_TOKEN}'
	@echo '  CHANGELOG_GITHUB_TOKEN=${CHANGELOG_GITHUB_TOKEN}'

check-env:
ifeq ($(wildcard .env),)
	@echo ".env file is missing. Create it from .env.sample"
	@exit 1
else
include .env
export
endif

build:
	cd bin && docker build -t python-requests .

pull: build
	docker pull ferrarimarco/github-changelog-generator

ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'

changelog: check-env
	@echo updating CHANGELOG...
	@docker run -it --rm \
		-v $(PWD):/usr/local/src/your-app \
		ferrarimarco/github-changelog-generator \
		-u ${GITHUB_OWNER} -p ${GITHUB_REPO} -t ${CHANGELOG_GITHUB_TOKEN}

	# commit master
	git add CHANGELOG.md
	git commit -m "updated CHANGELOG"
	git push

check-release: check-env
	# make sure we are in master
	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py check --branch=master

	# update versions and ask for confirmation
	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py

	VERSION=$(shell \
	docker run --rm -it \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		-v $(PWD)/versions.py:/usr/src/app/versions.py \
		python-requests update_release.py -v)

	@echo Version used will be $(VERSION)

	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py confirm

release: check-release
	# create branch and tag
	git checkout -b release-$(VERSION)
	git add .
	git commit -m "Prepared release $(VERSION)"
	git push --set-upstream origin release-$(VERSION)

	git tag $(VERSION)
	git tag -f qa-release
	git push --tags --force

	# updating CHANGELOG
	make changelog

	# create github release
	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py publish

	# git merge master
	git checkout master
	git merge release-$(VERSION)
	git push

push-qa:
	# update tags
	git tag -f qa-release
	git push --tags --force

	# updating CHANGELOG
	make changelog

push-prod:
	@# confirm push to production
	@docker run --rm -it \
		-v $(PWD):/usr/src/app \
		-v $(PWD)/bin/update_release.py:/usr/src/app/update_release.py \
		python-requests update_release.py confirm --prod

	# update tags
	git tag -f prod-release
	git push --tags --force

	# updating CHANGELOG
	make changelog
