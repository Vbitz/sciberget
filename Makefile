.PHONY: validate generate build release apps-json cvmfs-log desktop desktop-run cvmfs-server cvmfs-server-run

APP ?= nmap
IMAGE ?= sciberget-desktop:latest
CVMFS_SERVER_IMAGE ?= sciberget-cvmfs-server:latest

validate:
	@for f in recipes/*/build.yaml; do python3 builder/validation.py "$$f"; done

generate:
	python3 builder/build.py generate "$(APP)" --recreate

release:
	python3 builder/build.py generate "$(APP)" --recreate --generate-release
	python3 tools/generate_apps_json.py --releases-dir releases --output apps.json
	python3 cvmfs/generate_log.py --apps-json apps.json --output cvmfs/log.txt

build:
	python3 builder/build.py generate "$(APP)" --recreate --build --generate-release

apps-json:
	python3 tools/generate_apps_json.py --releases-dir releases --output apps.json

cvmfs-log:
	python3 cvmfs/generate_log.py --apps-json apps.json --output cvmfs/log.txt

desktop:
	python3 builder/build.py generate sciberget-desktop --recreate
	docker build -f build/sciberget-desktop/sciberget-desktop_0.1.0.Dockerfile \
		-t "$(IMAGE)" build/sciberget-desktop

desktop-run:
	docker run --rm -it --privileged --shm-size=1g -p 8080:8080 \
		-v "$$HOME/sciberget-storage:/sciberget-storage" "$(IMAGE)"

cvmfs-server:
	python3 builder/build.py generate sciberget-cvmfs-server --recreate
	docker build -f build/sciberget-cvmfs-server/sciberget-cvmfs-server_0.1.0.Dockerfile \
		-t "$(CVMFS_SERVER_IMAGE)" build/sciberget-cvmfs-server

cvmfs-server-run:
	docker run --rm -it --privileged -p 8081:80 \
		-e SCIBERGET_CVMFS_REPO=sciberget.local \
		-v sciberget-cvmfs-srv:/srv/cvmfs \
		-v sciberget-cvmfs-spool:/var/spool/cvmfs \
		-v sciberget-cvmfs-etc:/etc/cvmfs \
		"$(CVMFS_SERVER_IMAGE)"
