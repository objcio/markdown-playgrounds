# 🎰 Markdown Playgrounds for Swift

[![Swift 5](https://img.shields.io/badge/swift-5-ED523F.svg?style=flat)](https://swift.org/download/) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager) [![@objcio](https://img.shields.io/badge/contact-%40objcio-blue.svg?style=flat)](https://twitter.com/objcio)

## What it does

This app reads and writes Markdown documents that contain Swift code. The code can be executed too! You can run individual code blocks, or all the blocks in a file.

We're using this app to update our book [Advanced Swift](https://www.objc.io/books/advanced-swift/), and while writing [blog posts](https://www.objc.io/blog/archive/). We find it very useful, and we hope you do too.

## How it works

The app works by sending Swift code to a REPL instance, then reading back the results. Compared to Swift Playgrounds or Xcode's playgrounds, this is quite limiting, but it also means we can keep things simple.

<img width="912" alt="Screen Shot 2019-04-02 at 12 51 40" src="https://user-images.githubusercontent.com/5382/55397985-bdfca180-5547-11e9-8820-7cf3012c6e53.png">

## Learn more

We're documenting the building of this app on [Swift Talk](https://talk.objc.io/collections/markdown-playgrounds), a weekly video series of conversational live-coding hosted by [Chris Eidhof](https://twitter.com/chriseidhof) and [Florian Kugler](https://twitter.com/floriankugler).

<p align="center">
    <a href="https://talk.objc.io/episodes/S01E145-setting-up-a-document-based-app">
      <img width="600" alt="video cover" src="https://i.vimeocdn.com/video/769411132.jpg">
    </a>
</p>

The [first episode](https://talk.objc.io/episodes/S01E145-setting-up-a-document-based-app) previews the app, and is free to watch.

- 145: [Setting Up a Document Based App](https://talk.objc.io/episodes/S01E145-setting-up-a-document-based-app) — 🆓 Public
- 146: [Markdown Syntax Highlighting](https://talk.objc.io/episodes/S01E146-markdown-syntax-highlighting) — 🔒 Subscriber
- 147: [Executing Swift Code](https://talk.objc.io/episodes/S01E147-executing-swift-code) — 🔒 Subscriber
- 148: [String Handling](https://talk.objc.io/episodes/S01E148-string-handling) — 🔒 Subscriber


## Building

- You need to have [cmark](https://github.com/commonmark/cmark) installed *from master* (not via homebrew). If you use the version from homebrew, you won't get proper syntax highlighting (specifically: for inline elements).
- This project uses [Swift Package Manager](https://github.com/apple/swift-package-manager). You can either run "swift build" or do "swift package generate-xcodeproj"

Here are the steps as shell commands:

```sh
git clone https://github.com/commonmark/cmark
cd cmark
mkdir build
cd build
cmake ..
make
make test
make install
cd ../..

# Building this project
git clone https://github.com/objcio/markdown-playgrounds
cd markdown-playgrounds
swift build

# If you want to edit this in Xcode
swift package generate-xcodeproj
xed .
```

## Future Direction

This project could head in a number of directions, and there are many useful features we could add. Our main goal is to keep using this for authoring Swift-heavy Markdown, which will guide our decisions when we decide on new features.

To keep things simple, we have collected a list of todos in [todo.txt](todo.txt).

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
