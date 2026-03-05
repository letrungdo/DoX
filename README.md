# Do X

## Prerequisites Installation

- Xcode 16.4
- JDK version 17
- IDE: VSCode
- fvm: https://fvm.app/documentation/getting-started/installation
- make: https://formulae.brew.sh/formula

[![Netlify Status](https://api.netlify.com/api/v1/badges/bbdc9c84-6a3c-4f4c-ac12-d63ad0132147/deploy-status)](https://app.netlify.com/sites/do-x/deploys)

# Pre
> fvm dart pub global activate flutterfire_cli
> fvm dart pub global activate flutter_gen


### Config Google Sign In

Mã SHA-1: Bạn đã thêm mã SHA-1 (debug certificate) vào Firebase Console chưa? Nếu chưa, bạn chạy lệnh

```bash
cd android && ./gradlew signingReport
```

để lấy mã và dán vào phần cấu hình app trong Firebase.

https://console.cloud.google.com/auth/clients?project=do-appx

google-services.json: Đảm bảo tệp android/app/google-services.json đã được cập nhật sau khi bạn thêm SHA-1.

https://console.firebase.google.com/u/0/project/do-appx/settings/general/android:com.dox.app

