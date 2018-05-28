#!make
# Default values, can be overridden either on the command line of make
# or in .env

.PHONY: version vars \
	ps pull update-changelog \
	release push-qa push-prod

VERSION:=$(shell python update_release.py -v)

version:
	@echo APPLICATION: 
	@echo Version: $(VERSION)
	@echo ''
	@echo CHANGELOG GENERATOR:
	@docker run -it --rm \
		-v "$(pwd)":/usr/local/src/your-app \
		ferrarimarco/github-changelog-generator \
		--version

vars: check-env
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

pull:
	docker pull ferrarimarco/github-changelog-generator

ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'

changelog:
	@echo updating CHANGELOG...
	@docker run -it --rm \
		-v $(PWD):/usr/local/src/your-app \
		ferrarimarco/github-changelog-generator \
		-u ${GITHUB_OWNER} -p ${GITHUB_REPO} -t ${CHANGELOG_GITHUB_TOKEN}

	# commit master
	git add CHANGELOG.md
	git commit -m "updated CHANGELOG"
	git push


release:
	# make sure we are in master
	python update_release.py check --branch=master

	# update versions and ask for confirmation
	python update_release.py
	python update_release.py confirm

	# create branch and tag
	git checkout -b release-$(VERSION)
	git add .
	git commit -m "Prepared release $(VERSION)"
	git push --set-upstream origin release-$(VERSION)

	git tag $(VERSION)
	git tag -f qa-release
	git push --tags --force

	# updating CHANGELOG
	make update-changelog

	# create github release
	python update_release.py publish

	# cancel pre-update of versions
	git checkout versions.py

	# git merge master
	git checkout master
	git merge release-$(VERSION)
	git push

push-qa:
	# update tags
	git tag -f qa-release
	git push --tags --force

	# updating CHANGELOG
	make update-changelog

push-prod:
	@# confirm push to production
	@python update_release.py confirm --prod

	# update tags
	git tag -f prod-release
	git push --tags --force

	# updating CHANGELOG
	make update-changelog
