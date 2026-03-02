# CT-12: Debug & Dev Tooling

## Goal

Improve the development experience by ensuring debug mode always has testable data and by making it easy to preview the app at phone dimensions on desktop.

## Background

Two recurring pain points during development:

1. Starting the app in debug mode sometimes results in no review cards being available, making it impossible to test drill mode without manually seeding data first.
2. The desktop debug window doesn't match phone dimensions, so layout issues only surface when testing on a real device.

## Specs

- `architecture/testing-strategy.md` — dev seed function behavior

## Tasks

- CT-12.1: Always seed review cards in debug mode
- CT-12.2: Phone-sized debug window
