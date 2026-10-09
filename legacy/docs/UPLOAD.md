# Upload to GitHub

GitHub connector returned HTTP 403 on the initial README write. No remote files were written by this session.

Extract the source archive, open the project directory and run:

```bash
git init -b main
git remote add origin https://github.com/Petasus69/kcd2-dice.git
git add .
git commit -m "Add offline medieval dice game and Android build"
git push -u origin main
```

If you already cloned the empty repository, copy the archive contents into the clone and skip init/remote add.
GitHub Actions requires enabling Actions for the repository, then produces an APK artifact after each main-branch push.
