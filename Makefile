# for Android debugging:
# sudo usermod -aG plugdev $LOGNAME & logout/login
# enable USB debugging + Dateiübertragung
run:
	flutter run --device-id chrome

run-phone:
	flutter run --device-id 7e62592d

release:
	flutter build apk --release

install-on-phone: release
	flutter install --device-id 7e62592d

update-icons:
	flutter pub get
	flutter pub run flutter_launcher_icons:main
	flutter clean