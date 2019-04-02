# Markdown Playgrounds for Swift

This app is a way to read and write Markdown documents that contain Swift code. Swift code can be executed as well: we can run individual code blocks, as well as run all the code blocks in a file. We use this app while writing our book [Advanced Swift](https://www.objc.io/books/advanced-swift/) and while blogging.

The app works by sending Swift code into a REPL instance, and reading the results back. Compare to Swift Playgrounds or Xcode's playgrounds, this is quite limiting, but it also means we can keep things simple.

<img width="912" alt="Screen Shot 2019-04-02 at 12 51 40" src="https://user-images.githubusercontent.com/5382/55397985-bdfca180-5547-11e9-8820-7cf3012c6e53.png">

We're documenting the building of this app on [Swift Talk](https://talk.objc.io/collections/markdown-playgrounds).

## Building

- You need to have [cmark](https://github.com/commonmark/cmark) installed from master (not via homebrew). If you use the version from homebrew, you won't get proper syntax highlighting (especially for inline elements).
- This project uses Swift Package Manager. You can either run "swift build" or do "swift package generate-xcodeproj"

## Future Direction

This project could take a lot of different directions, and there are a lot of useful features we could add. Our main goal is to keep using this for authoring Swift-heavy Markdown, and when deciding about features, that'll be guiding our decisions.

To keep things simple, we have collected a list of todos in [todo.txt](todo.txt).
