# jasonbirchall dotfiles

This repository contains both dotfile configuration and brew install packages intended to run on a mac M1. The bits that are rather personal to my setup are as follows:

- I use `${HOME}/Documents/workarea` to clone my git repositories. This is my main development directory.
- I use the Keychron K2 keyboard, which is compact. Some keybindings may seem peculiar, but the keyboard is small and some of the keys don't follow ISO UK or mac UK layouts.

The repository uses a combination of [dotbot](https://github.com/anishathalye/dotbot) to create symlinks etc, and [brew bundle](https://github.com/homebrew/homebrew-bundle) to install HomeBrew, [whalebrew](https://github.com/whalebrew/whalebrew) and [mas](https://github.com/mas-cli/mas) packages and updates.

## Install

Clone this repository locally, then:

```
sh ./install
```
