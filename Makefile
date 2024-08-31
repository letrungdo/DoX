clean:
	fvm flutter clean
	fvm flutter pub get
	fvm flutter pub run build_runner build --delete-conflicting-outputs

gen:
	fvm flutter gen-l10n
	fvm flutter packages pub run build_runner build --delete-conflicting-outputs

l10n:
	fvm flutter gen-l10n
