# BetterNotes Privacy Policy

**Effective date:** 2026-11-07
**Developer:** Azrin Freeman ("I", "me")
**Contact:** azrinfreeman2@gmail.com
**Project:** https://github.com/Azrinfreeman/BetterNotes

BetterNotes is a notes app. Your notes belong to you. This policy explains what data the app handles and where it goes.

## Summary

- Notes, images and settings are stored **on your device**.
- I run no server that receives your notes. I do not collect analytics, advertising identifiers or crash reports.
- Two features send data off your device, and **only if you turn them on**: Google Drive backup and cloud sync.

## Data stored on your device

Notes, attachments and pictures, tags, reminders and app settings are stored in the app's local data folder on your computer. I cannot see them. Uninstalling the app or deleting that folder removes them, unless you have made a backup.

## Google Drive backup (optional)

If you choose **Back up to Google Drive**, you sign in with your Google account in your web browser.

**What the app requests**

| Permission | Why |
| --- | --- |
| `drive.appdata` | Lets BetterNotes read and write one hidden, app-specific folder in your own Google Drive. The app cannot see, list or change any of your other Drive files. |
| `openid` and `email` | Shows which Google account is connected. |

**What is uploaded:** a backup file (a zip) containing your notes, images and settings. The backup is stored only in that hidden folder in **your** Google Drive. It counts against your Google storage quota. The app keeps the newest 3 backups per device and deletes older ones from that folder.

**Automatic backup:** if you turn on daily automatic backup, the app stores a Google refresh token in the Windows Credential Manager so it can upload without asking you to sign in again. If automatic backup is off, no token is saved. Turning it off or disconnecting removes the stored token.

**Who sees the data:** only you and Google, under Google's own terms. I never receive your Google tokens, your email address or your backups. The sign-in runs between your computer and Google directly.

**Revoking access:** you can disconnect inside the app, or remove BetterNotes at any time at https://myaccount.google.com/permissions. You can delete backups by removing the app's hidden data from your Google Drive settings ("Manage apps").

BetterNotes's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements. Google data is used only to provide the backup and restore feature. It is not sold, not used for advertising, not used to train AI models, and not read by humans.

## Cloud sync (optional)

If a build of BetterNotes is configured with a cloud sync service and you sign in, your notes and note pictures are sent to that service (Supabase) and stored under your account so you can use them on more than one device. Sign-in is by Google or another provider you choose; the provider tells the service your name and email so it can create your account. Pictures are kept in a private storage area readable only by your account. If you do not sign in, nothing is sent. You can delete your synced data by deleting your notes inside the app or by contacting me at the address above.

## Other data

- **Browser links:** the app may open links in your default browser. Those sites have their own policies.
- **Update checks and installer:** the app does not phone home. Downloads come from GitHub, which has its own privacy policy.
- **Children:** BetterNotes is not directed to children under 13 and I do not knowingly collect their data.

## Security

Backup files go to Google over HTTPS. Refresh tokens are held in the Windows Credential Manager. Local notes are protected by your Windows account. Backups in your Drive are protected by your Google account, so keep it secured with a strong password and two-step verification.

## Your choices

You can use BetterNotes fully offline, decline Google Drive and cloud sync, disconnect them at any time, and delete your data as described above.

## Changes

If this policy changes, I will update the date at the top and publish the new version at the same address. Material changes will also be noted in the release notes.

## Contact

Questions or requests: azrinfreeman2@gmail.com
