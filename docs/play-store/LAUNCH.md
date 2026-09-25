# Launching Trader's Mind on Google Play

Most of this works from a phone browser. Uploading files is easier on a computer. Expect about **3–4 weeks** from sign-up to public, mostly waiting on verification and the 14-day test.

## 1. Developer account (day 1, then wait 1–3 days)

1. Go to <https://play.google.com/console/signup> and choose **Yourself** (a personal account).
   An organization account skips the 14-day test but needs a registered business with a D-U-N-S number.
2. Pay the one-time **$25** fee.
3. Verify your identity with a government ID, and verify a phone number.
4. Install the **Google Play Console** app on your Android phone and sign in. New accounts must confirm they own a real Android device.
5. Pick a **developer name**. It is shown publicly under the app, so "vexatrov" or your name both work.
6. Use a contact email you're happy to have shown publicly (see `listing.md`).

## 2. Turn on signed builds (5 minutes)

You have `traders-mind-upload-key.txt` and `upload-keystore.jks` from this session. Keep both somewhere private, such as a password manager or a private Drive folder.

1. On GitHub, open the repo → **Settings → Secrets and variables → Actions → New repository secret**.
2. Add `KEYSTORE_PASSWORD` and `KEYSTORE_BASE64`, copying both values exactly from the text file.
3. Go to **Actions → Android → Run workflow**, or push any change.
4. When it finishes, the newest **Release** has `app-release.aab`. That is the file for Play.

Once the key is in place, the APKs on GitHub are signed with it too. Your installed test copy was signed with a throwaway key, so update it once this way:
Settings → **Save backup file** (to Downloads or Drive), uninstall, install the new APK, then **Restore from backup**.

## 3. Create the app in Play Console

**Create app**, then fill in:
- Name: `Trader's Mind: Mental Game Log`, language English (United States)
- App, Free
- Tick the declarations

Then complete everything in **Policy → App content** using `console-answers.md`, and the **Main store listing** using `listing.md` plus the images in `graphics/` and `screenshots/`.

## 4. Internal test (try it yourself first)

1. **Test and release → Testing → Internal testing → Create new release.**
2. When asked about **Play App Signing**, keep the default (Google manages the app signing key). Your upload key only proves uploads come from you, and a lost one can be reset.
3. Upload `app-release.aab`. For release notes, `First test build.` is enough.
4. Under **Testers**, create an email list with your own Google account. Save, then roll out.
5. Open the opt-in link on your phone and install from Play. Save a backup file first, then uninstall the sideloaded copy.

Test on the real phone (these can't be tested in the cloud build):
- [ ] Start the check-in timer. Reminders arrive, and tapping one opens the check-in.
- [ ] Reboot the phone during a session. Reminders still arrive.
- [ ] Settings → automatic backup to Google Drive. Close the app, and the file updates.
- [ ] Save backup file, uninstall, reinstall, Restore from backup. Everything comes back.
- [ ] Links on the About screen open the browser.
- [ ] Dark mode and large system font look right.

## 5. Closed test: 12 testers for 14 days (required for new personal accounts)

1. **Testing → Closed testing → Create track** (or use "Alpha"), and upload the same `.aab`.
2. Add testers with a **Google Group**, which is easiest to share, or an email list.
3. Send them the opt-in link. They need an Android phone, to tap "Become a tester" and to install the app.
4. **At least 12 testers must stay opted in for 14 days in a row.** Recruit 15–20 in case some drop out.
5. Ask them to actually use it and send feedback. Ship one or two updates during the 14 days, because Google asks about this afterwards.

Where to find testers:
- Friends and family with Android phones. They don't need to trade to open it a few times.
- Trading friends, Discords and forums you already belong to. Be upfront that it's a free, private journal in testing.
- Tester-swap communities such as Reddit's r/AndroidClosedTesting and r/TestersCommunity, where developers test each other's apps.

## 6. Apply for production

After 14 days, **Dashboard → Apply for production**. You answer a short questionnaire: how you recruited testers, what feedback you got, what you changed, and why the app is ready. Review usually takes a few days, sometimes up to a week or two.

## 7. Release

**Production → Create new release**, upload the latest `.aab`, and roll out. A staged rollout at 20% first is a safe start.

## Every update after that

Push to the branch. CI tests the app, builds it and attaches a new `.aab` with a higher version code to a GitHub Release. Upload that file to a new Play release.

This can be fully automated later with a Play service account and one more CI step.

## If something is rejected

The email names the policy. Common first-launch issues:
- Metadata that seems to imply the app is official. The listing already states it is independent.
- A privacy policy link that doesn't load. Check it in a private browser tab.
- Missing Data safety or content rating answers.

Fix the issue and resubmit. Rejections are normal and not a strike on the account.
