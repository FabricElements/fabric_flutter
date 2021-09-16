# fabric_flutter

Native components and helpers

## Getting Started

When adding a new component make sure to include an example in the example project

### Run locally

```cmd
flutter run --no-sound-null-safety --hot
```

```cmd
flutter run --hot web --no-sound-null-safety
```

## Debug

### Android

If the android emulator is not working on debug mode on the computer, specifically the google sign in, there are a few
things which may need to be done.

- Open android folder in Android Studio, sync gradle and try to build project
- Check and fix any errors related to the sync or build
- Double check applicationid name
- Make sure all packeges (including Kotlin version) in the android/gradle and android/app/gradle are up to date
- Check support email
- add your sha1 and sha256 to the android app, instructions to get
  sha's [here](https://developers.google.com/android/guides/client-auth)
- re-download google-services.json for project
- *build -> clean project* in Android Studio
- *build -> build project* in Android Studio
- launch app

### Run locally

```cmd
flutter run --no-sound-null-safety --hot
```

## Release

### iOS

```cmd
flutter build ios --release --no-sound-null-safety
```

### Android

```cmd
flutter build appbundle --release --no-sound-null-safety
```

### Ignore files

#### Ignore

```cmd
git update-index --skip-worktree default_values.txt
```

#### Restore

```cmd
git update-index --no-skip-worktree default_values.txt
```

#### You can get a list of files that are marked skipped with:

```cmd
git ls-files -v . | grep ^S
```

## Rebuild Annotations

```cmd
flutter pub run build_runner build --delete-conflicting-outputs
```

## Contributing

Please check [CONTRIBUTING](CONTRIBUTING.md).

## License

Released under the [BSD 3-Clause License](LICENSE.md).