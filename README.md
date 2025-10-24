Alex' Library for Homebrew Formulae
===================================

This Git repository is a so called "[brew tap]" and contains additional
formulae and commands for [Homebrew], a package manager for macOS and Linux.

Enabling this repository in homebrew
------------------------------------

Simply use the following command to add and enable this external repository
in your local [Homebrew] installation:

`brew tap alexbarton/alex`

Now you can use all the regular `brew` subcommands like `search`, `install`,
`upgrade` etc. to handle the formulae included here. Please see the [brew tap]
documentation for details.

Subcommands provided by this repository
---------------------------------------

The following additional `brew` subcommands are provided by this repository:

`brew rdeps <installed_formula>`
: Show "reverse dependencies" of a formula. The reverse of `brew deps`. This is
a simple wrapper for `brew uses --installed --recursive`.

`brew run`
: Combine `brew update`, `brew outdated`, `brew upgrade` and `brew cleanup`
into one command. And handle pinned formulae accordingly.

[Homebrew]:https://brew.sh
[brew tap]:https://docs.brew.sh/Taps
