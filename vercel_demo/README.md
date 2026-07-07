# Avoid Call Vercel Demo

This folder contains the JavaScript mock API used for the Vercel demo.

Build the Flutter web app with:

```sh
cd main_project_app
flutter build web --release \
  --dart-define=APP_MODE=local \
  --dart-define=LOCAL_TEST_MODE=true \
  --dart-define=API_URL=/api
```

Then deploy a directory that combines `main_project_app/build/web/*` with this
folder's `api/` and `vercel.json`.
