# stratos.background

This is the core code for the Stratos extension background page. In particular,
it handles re-authentication and the actual sync process.

## Sync implementation notes

All uploaded captures have an app property set to the capture ID. This makes it
easy to check if one is already uploaded, even if the user moves it around, so
they're free to re-organize their captures as they see fit.

Uploads occur sequentially. Given the file size of videos in particular,
parallel uploads may not give that much of a speed gain, but it could cause
race issues where a capture gets uploaded twice because it was trying to be
synced multiple times at once. This could be handled with more checks in the
sync engine, but that's out of the project scope for now.
