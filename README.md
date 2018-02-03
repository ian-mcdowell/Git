# Git

<p align="center">
  <b>Git</b> &bull;
  <a href="https://github.com/IMcD23/InputAssistant">InputAssistant</a> &bull;
  <a href="https://github.com/IMcD23/TabView">TabView</a> &bull;
  <a href="https://github.com/IMcD23/TiltedTabView">TiltedTabView</a>
</p>

--------

Wrapper around libgit2, written in Swift

[![Build Status](http://img.shields.io/travis/IMcD23/Git.svg)](https://travis-ci.org/IMcD23/Git)
[![Version](https://img.shields.io/github/release/IMcD23/Git.svg)](https://github.com/IMcD23/Git/releases/latest)
![Package Managers](https://img.shields.io/badge/supports-Carthage-orange.svg)
[![Contact](https://img.shields.io/badge/contact-%40ian__mcdowell-3a8fc1.svg)](https://twitter.com/ian_mcdowell)


# Requirements

* Xcode 9 or later

# Usage

Take a look at the documentation for each class for information on how to use it.

# Installation

## Carthage
To install Git using [Carthage](https://github.com/Carthage/Carthage), add the following line to your Cartfile:

```
github "IMcD23/Git" "master"
```

## Submodule
To install Git as a submodule into your git repository, run the following command:

```
git submodule add -b master https://github.com/IMcD23/Git.git Path/To/Git
git submodule update --init --recursive
```

Then, add the `.xcodeproj` in the root of the repository into your Xcode project, and add it as a build dependency.

## ibuild
A Swift static library of this project is also available for the ibuild build system. Learn more about ibuild [here](https://github.com/IMcD23/ibuild)

# Author
Created by [Ian McDowell](https://ianmcdowell.net)

# License
All code in this project is available under the license specified in the LICENSE file. However, since this project also bundles code from other projects, you are subject to those projects' licenses as well.
