# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

.PHONY: zip

zip:
	rm -f stratos.zip
	cd build; zip -r ../stratos.zip \
		-x'packages/*' -x'.dart_tool/*' -x'.build.manifest' -x'.packages' \
		-x'*.dart' -x'*.map' -x'*.deps' -x'manifest.*.json' .
