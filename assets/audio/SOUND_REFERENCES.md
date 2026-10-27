# Lobby audio references

All choices below are Creative Commons Zero (CC0) according to the linked source pages. They are references only: download from the original author, trim or normalize as needed, upload through Roblox Creator Dashboard, then replace the `SoundId` in `LobbyClient.client.luau` with the uploaded `rbxassetid`.

## Chanting

- [Thai Buddhist Monk Chant](https://freesound.org/people/Alex_hears_things/sounds/274835/) — 46 seconds, Thai Buddhist prayer; ideal as a very quiet positional sound at the main Buddha statue.
- [Monks praying in temple at night](https://freesound.org/people/nonzeroenfilade/sounds/172104/) — 3m21s, Chiang Mai temple recording; use a 30–60 second excerpt at low volume for the main ambience loop.

## Howl and eerie moments

- [Wolf howl](https://freesound.org/people/NaturesTemper/sounds/398430/) — 8 seconds; trigger rarely from the forest, with 3D rolloff, rather than looping it.

## Night ambience

- [Night Ambience](https://freesound.org/people/parret/sounds/481883/) — 5m37s of insects/night air; use as the low-volume base layer beneath the existing crickets.

## Roblox upload checklist

1. Download while logged in to Freesound and keep the source link with the project.
2. Trim loops so their starts/ends crossfade cleanly; export mono for positional sounds and stereo for global ambience.
3. Upload from Creator Dashboard, wait for moderation, then copy the resulting audio asset ID.
4. Replace only the placeholder `SoundId` values after the assets are approved; do not rely on a Freesound URL directly at runtime.
