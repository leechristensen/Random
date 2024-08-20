# Overview
Automates setting up a fresh Mythic dev installation. 

__`clean.sh`__
Cleans up an installation. 
- Docker: Deletes deletes all containers, old verions of images, and prunes the build cache.
- Resets the git repo back to HEAD, cleans up previous files, and restores permission back to the user (not root)

__`start.sh`__
Starts Mythic:
* Starts mythic with some preconfigured options
* Configures a pre-generated cert
* Start the HTTP profile and Poseidon
* Configures a Poseidon payload with a hardcoded UUID+no encryption (no need to rebuild a payload!)

# Usage
```
cd Mythic
~/code/Random/mythic/clean.sh && ~/code/Random/mythic/start.sh
```