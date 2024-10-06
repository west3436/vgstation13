CONTRIBUTING TO VGSTATION
=========================

# General rules

* **Pull requests must be atomic.**  Change one set of related things at a time.  Bundling sucks for everyone.
 * This means, primarily, that you shouldn't fix bugs **and** add content in the same PR. When we mean 'bundling', we mean making one PR for multiple, unrelated changes.
* **Test your changes.**  PRs that do not compile will not be accepted.
 * Testing your changes locally is incredibly important. If you break the serb we will be very upset with you.
* **Large changes require discussion.**  If you're doing a large, game-changing modification, or a new layout for something, discussion with the community is required as of 26/6/2014.  Map and sprite changes require pictures of before and after.  **MAINTAINERS ARE NOT IMMUNE TO THIS.  GET YOUR ASS IN THE CODE DISCORD.** (link in README.md)
* Merging your own PRs is considered bad practice, as it generally means you bypass peer review, which is a core part of how we develop.

# Balance changes
 * **Balance changes must require that feedback be sought out from the players.** For example, server polls. This does not mean you pop into #code-talk in Discord and ask about it once. Good examples include:
   * Server polls. Duration of the poll should be longer than 24 hours at minimum. Use best judgment.
   * Bringing attention to your PR via in-game OOC, ideally over several time slots.
 * **Balance change PRs need changelogs. Always.**
 * **If you are a collaborator,** allow sufficient time for feedback to be gathered, and make sure that it *has* been gathered.

It is also suggested that you hop into irc.rizon.net #vgstation to discuss your changes, or if you need help.

## Modifying MILLA-vg

Our atmos engine, MILLA-vg, is in the `milla/` directory. It's written in Rust for performance reasons, which means it's not compiled the same way as the rest of the code. If you're on Windows, you get a pre-built copy by default. If you're on Linux, you built one already to run the server.

If you make changes to MILLA, you'll want to rebuild. This will be very similar to RUSTG:
https://github.com/ParadiseSS13/rust-g
The only difference is that you run `cargo` from the `milla/` directory, and don't need to speify `--all-features` (though it doesn't hurt).

The server will automatically detect that you have a local build, and use that over the default Windows one.

When you're ready to make a PR, please DO NOT modify `milla.dll` or `tools/ci/libmilla_ci.so`. Leave "Allow edits and access to secrets by maintainers" enabled, and post a comment on your PR saying `!build_milla`. A bot will automatically build them for you and update your branch.

# Other considerations

* If you're working with PNG and/or DMI files, you might want to check out and install the `pre-commit` git hook found [here](tools/git-hooks). This will automatically run `optipng` (if you have it) on your added/modified files, shaving off some bytes here and there.
