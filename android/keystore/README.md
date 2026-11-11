# Release keystore

Place `palturo-release.jks` here for local release builds. The keystore and
`android/key.properties` are gitignored. In CI, inject the keystore from a
secret store and set `storeFile` to its path.

Losing this key prevents updates to an already-published package unless Play
App Signing is used. Back it up in a secret manager, not in the repository.
