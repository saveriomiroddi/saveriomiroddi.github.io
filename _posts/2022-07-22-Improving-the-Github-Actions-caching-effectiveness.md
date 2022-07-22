---
layout: post
title: "Improving the Github Actions caching effectiveness"
tags: [cloud,git,github,performance,ruby,rust,sysadmin]
---

Github Actions are the new de facto standard for projects CI (and many other tasks).

Through a certain action, actions support data caching. I was very surprised though, when I've noticed that caching, as frequently described, has a very severe limitation - it's not shared across PRs; this limits its performance severely.

In this small article, I'll describe the problem, the solution, and two preset workflows, in Ruby and Rust.

Content:

- [The Problem](/Improving-the-Github-Actions-caching-effectiveness#the-problem)
- [The solution](/Improving-the-Github-Actions-caching-effectiveness#the-solution)
- [Implementations](/Improving-the-Github-Actions-caching-effectiveness#implementations)
  - [Ruby](/Improving-the-Github-Actions-caching-effectiveness#ruby)
  - [Rust](/Improving-the-Github-Actions-caching-effectiveness#rust)
- [Conclusion](/Improving-the-Github-Actions-caching-effectiveness#conclusion)

## The Problem

If a dev sets up CI as typically described, they will get caching; opening a PR will have the first workflow run fill the cache, then subsequent runs of the same PRs will reuse it.

This is very inefficient; if the cached operation is slow (e.g. installing many Ruby gems, or building a large Rust project), the first workflow run for each PR will take a considerable time.

The reason for this is actually explained in the [GitHub Actions documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows#restrictions-for-accessing-a-cache) (emphasis mine):

> Restrictions for accessing a cache
>
> A workflow can access and restore a cache created in the current branch, the base branch (including base branches of forked repositories), or the default branch (usually main). For example, a cache created on the default branch would be accessible from any pull request. Also, if the branch feature-b has the base branch feature-a, a workflow triggered on feature-b would have access to caches created in the default branch (main), feature-a, and feature-b.
>
> Access restrictions provide cache isolation and security by creating a logical boundary between different branches. For example, **a cache created for the branch feature-a (with the base main) would not be accessible to a pull request for the branch feature-c (with the base main)**.
>
> Multiple workflows within a repository share cache entries. A cache created for a branch within a workflow can be accessed and restored from another workflow for the same repository and branch.

Surprisingly, this detail is frequently omitted. For example, this is a the [Ruby section](https://github.com/actions/cache/blob/main/examples.md#ruby---bundler) of the caching action:

> Caching gems with Bundler correctly is not trivial and just using actions/cache is not enough.
>
> Instead, it is recommended to use ruby/setup-ruby's bundler-cache: true option whenever possible:
>
>     - uses: ruby/setup-ruby@v1
>       with:
>         ruby-version: ...
>         bundler-cache: true

The `setup-ruby` action [doesn't mention it as well](https://github.com/ruby/setup-ruby#caching-bundle-install-automatically).

## The solution

A convenient solution to improve cache reuse is to build it on every main branch push; this way:

- the cache is always incrementally built (both for the main branch and the PRs);
- in particular, the PRs will build incrementally on top of the main branch cache.

Note that if there are no related changes (e.g. no new libraries added), the cache will be fully recycled.

## Implementations

I provide two sample implementations here, for Ruby and Rust.

Please note that they're intentionally bare-bones; for real projects, there are many small things to add (names, conditions, job matrices etc.).

### Ruby

In Ruby, we're going to rely on the `ruby-setup` action.

Main branch workflow:

```yml
on:
  push:
    branches: [ $default-branch ]
jobs:
  build_ruby_cache:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
```

The following is a very basic example of a workflow CI to run on PRs:

```yml
on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
    - run: bundle install
    - run: bundle exec rspec
```

Things are simple in Ruby land 😄

### Rust

Rust, in principle, is the same; the complication is that we need to differentiate between build (Cargo) actions.

For example, if we run Clippy, its data is shared with (Cargo) build data, but it's not the same; therefore, we need to build both caches.

Something else to keep in mind is that getting caching right in Rust projects is very important, as the compiler is "not exactly a speed demon" 😄, and build time is consumed in large quantity with extreme ease.

In this example, we'll just perform two PR jobs:

- project formatting check;
- Clippy correctness checks.

and fail the build if any fails.

Main branch workflow:

```yml
on:
  push:
    branches: [ $default-branch ]
jobs:
  build_clippy_cache:
    name: Build Clippy cache
    runs-on: ubuntu-latest
    steps:
    # Don't forget to install dev libraries 🙂
    - run: sudo apt install libasound2-dev libudev-dev
    - uses: actions/checkout@v3
    - uses: actions/cache@v3
      with:
        path: |
          ~/.cargo/bin/
          ~/.cargo/registry/index/
          ~/.cargo/registry/cache/
          ~/.cargo/git/db/
          target/
        key: ${{ '{{' }} runner.os }}-cargo-${{ '{{' }} hashFiles('**/Cargo.lock') }}
    - uses: actions-rs/cargo@v1
      with:
        command: clippy
```

The cached paths are the standard cargo cache locations, and the project build directory.

Now, the PR workflow:

```yml
on:
  pull_request:

jobs:
  check_formatting:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/cargo@v1
        with:
          command: fmt
          args: --all -- --check
  clippy_correctness_checks:
    runs-on: ubuntu-latest
    steps:
      - run: sudo apt install libasound2-dev libudev-dev
      - uses: actions/checkout@v3
      - uses: actions/cache@v3
        with:
          path: |
            ~/.cargo/bin/
            ~/.cargo/registry/index/
            ~/.cargo/registry/cache/
            ~/.cargo/git/db/
            target/
          key: ${{ '{{' }} runner.os }}-cargo-${{ '{{' }} hashFiles('**/Cargo.lock') }}
      - uses: actions-rs/cargo@v1
        with:
          command: clippy
          args: -- -W clippy::correctness -D warnings
```

Nice and easy! Note how we don't cache `cargo fmt`, since it doesn't involve any build.

When adding, as typical, full project builds (for testing, release, etc.), the corresponding (Cargo) build jobs need to be added to the main branch workflow.

Github Actions provide 10 GB for each repository, which is enough space to build a mid-sized Rust project for multiple platforms.

## Conclusion

I'm baffled why this topic is not frequently mentioned, and indeed, not all the devs are aware of it.

Regardless, solving the problem is easy, both conceptually, and implementationally.

Happy CI 😄
