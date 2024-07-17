# for Android debugging:
# sudo usermod -aG plugdev $LOGNAME & logout/login
# enable USB debugging + Dateiübertragung
run:
	flutter run --device-id chrome

run-phone:
	flutter run --device-id 7e62592d

release:
	flutter build apk

install-on-phone:
	flutter build apk
	flutter install --device-id 7e62592d