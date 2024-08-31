clean:
	fvm flutter clean
	fvm flutter pub get
	fvm dart run build_runner clean
	fvm dart run build_runner build --delete-conflicting-outputs

gen:
	fvm flutter gen-l10n
	# fvm dart run build_runner clean
	fvm dart run build_runner build --delete-conflicting-outputs

l10n:
	fvm flutter gen-l10n

build-apk:
	fvm flutter build apk --release \
		--dart-define-from-file envs/dev.env \
		--obfuscate --split-debug-info=build/obfuscate \
		--build-name 1.0.0 --build-number 1

build-ipa:
	fvm flutter build ipa --release \
		--dart-define-from-file envs/dev.env \
		--obfuscate --split-debug-info=build/obfuscate \
		--build-name 1.0.0 --build-number 1

build-macos:
	fvm flutter build macos \
		--dart-define-from-file envs/dev.env \
		--obfuscate --split-debug-info=build/obfuscate \
		--build-name 1.0.0 --build-number 1

build-windows:
	fvm flutter build windows \
		--dart-define-from-file envs/dev.env \
		--obfuscate --split-debug-info=build/obfuscate \
		--build-name 1.0.0 --build-number 1
