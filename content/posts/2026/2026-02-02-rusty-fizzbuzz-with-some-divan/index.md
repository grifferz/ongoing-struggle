+++
title = "Rusty Fizz buzz with some Divan"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
A Rust video by Andy Balaam inspires me to look into benchmarking with Divan
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "rustlang",
]

[extra]
toc_levels = 1
+++

Recently I watched [a Rust video by Andy Balaam] covering a test-driven
implementation of one brand of [the Fizz buzz game]. Watching it inspired me
to learn about benchmarking Rust with [Divan], and that's what this write up
is about.

[a Rust video by Andy Balaam]:
  https://video.infosec.exchange/w/2dEHo81R7ozrfohX2PARWt
[the Fizz buzz game]: https://en.wikipedia.org/wiki/Fizz_buzz
[Divan]: https://github.com/nvzqz/divan

{{ toc() }}

## Watch the video first!

I'm not sure that this article will make much sense unless you watch [Andy's
video] first, or possibly at the same time.

[Andy's video]: https://video.infosec.exchange/w/2dEHo81R7ozrfohX2PARWt

So there I was enjoying Andy's video. When he got to the part where he'd
implemented his variation of Fizz buzz to the point that it passed all his
unit tests he started wondering about what changes he could make to make the
code more pleasing and possibly more performant.

Throughout this Andy stated repeatedly that it's always a bad idea to do
performance changes without checking if they actually make things better (or
even if they are needed), but his main focus was on correctness and how you
might test for that as the code evolves.

I'd seen a few people use Divan for benchmarking Rust code and thought to
myself, oh, as a learning exercise for Divan I could write out the different
versions of Andy's implementation and try benchmarking them. So [that's what
I've done].

[that's what I've done]: https://github.com/grifferz/fzbz

{% admonition_body(type="note") %}

1. I am a novice with Rust and I've never previously actually used Divan! 😀
2. I do realise that an implementation of Fizz buzz isn't a great thing to try
   to benchmark as it's rather too simple. This was mainly about learning how
   to use the crate.

Nevertheless, I did find out some things that interested me.

{% end %}

## Fizz buzz implementations

In [the `src/lib.rs` file] you can see all the different implementations that
Andy came up with, in the order that he discussed them in his video. Of
course, in his video he was just iterating on the one implementation, but I've
captured what I think were each of the key stages and kept them as separate
functions so they can be evaluated together. They are:

[the `src/lib.rs` file]: https://github.com/grifferz/fzbz/blob/main/src/lib.rs

### `naive()`

A straightforward test of every scenario as a list of `if …` / `else if …`
predicates.

### `mod_then_match()`

A neater looking version which does all the tests first and then uses a single
`match` block to check all possible states.

### `early_return_before_mod()`

Like `mod_then_match()`, but first checks for the case where both '5' and '7'
appear in the number string in order to short circuit before doing any of the
modulus tests.

### `single_string_scan()`

Like `early_return_before_mod()` but instead of doing multiple checks with
`n_str.contains(…)`, this version does just one scan through the string.

### `single_string_scan_early_fizzbuzz()`

Like `single_string_scan()` but do a check for the "FizzBuzz" case due to
character matches, to be able to sometimes avoid having to do any modulus
checks.

### And one more…

At the end I added one more of my own, and one variant on it. Read on!

## Testing

Andy spent a lot of time covering his testing strategy, probably you could say
it was the main thrust of the video. I only altered it to use [the test_case
crate] so that I could pass in a pointer to a function that is the desired
Fizz buzz implementation to be tested. That way it was easy to do all the same
unit tests on every implementation.

[the test_case crate]: https://docs.rs/test-case/latest/test_case/

You can see them all in [the `src/main.rs` file], but here's an example of one
of the unit tests.

[the `src/main.rs` file]:
  https://github.com/grifferz/fzbz/blob/main/src/main.rs#L57

```rust,name=src/main.rs
    #[test_case(naive ; "using naive implementation")]
    #[test_case(mod_then_match ; "using mod first then match cases implementation")]
    #[test_case(early_return_before_mod ; "using early return before mod")]
    #[test_case(single_string_scan ; "using single string scan")]
    #[test_case(single_string_scan_early_fizzbuzz ; "using single string scan with early fizzbuzz shortcircuit")]
    fn fizzbuzz_all_counts_up_to_max(fzbz_fn: fn(i32) -> Answer) {
        let answers = fizzbuzz_all(fzbz_fn, 50);
        assert_eq!(answers[0], Number(1));
        assert_eq!(answers[4], Buzz);
        assert_eq!(answers[6], Fizz);
        assert_eq!(answers[34], FizzBuzz);
        assert_eq!(answers[35], Number(36));
        assert_eq!(answers.len(), 50);
    }
```

## Benchmarking with Divan

Again, a reminder that Andy was at pains to point out that he didn't know if
any of the changes he was making were actually making the code more performant
and that wasn't the goal of his video. I was interested in that though!

The Divan crate has good instructions, but basically it's a case of adding it
to [Cargo.toml] as a development dependency and then adding a `[[bench]]`
section:

[Cargo.toml]: https://github.com/grifferz/fzbz/blob/main/Cargo.toml#L6

```toml,name=Cargo.toml
[dev-dependencies]
divan = "0.1.21"
test-case = "3.3.1"

[[bench]]
name = "fizzbuzz"
harness = false
```

{% admonition_body(type="info") %}

The `harness = false` bit disables the built-in benchmarking so that Divan can
take over.

{% end %}

The `name = "fizzbuzz"` part corresponds to [my `benches/fizzbuzz.rs` file]
where my benchmark functions live. In that file are just a list of functions
each of which calls an implementation of Fizz buzz.

[my `benches/fizzbuzz.rs` file]:
  https://github.com/grifferz/fzbz/blob/main/benches/fizzbuzz.rs

```rust,name=benches/fizzbuzz.rs
#[divan::bench]
fn naive_bench() -> Vec<Answer> {
    fizzbuzz_all(naive, divan::black_box(2_000_000))
}
```

`#[divan::bench]` tells `rustc` that the following function is a Divan
benchmark and benchmarking code should be generated. The
`divan::black_box(2_000_000)` part avoids the compiler optimising away code
that seemingly is not actually used for anything.

This is going to generate Fizz buzz for every number between 1 and 2,000,000
many _many_ times and sample how long it took to do it, with that particular
implementation (`naive()`).

I'm pretty sure there is a nicer way to organise that `benches/fizzbuzz.rs`
file but this was good enough for my first try!

### Results

On my (8 year old, rather slow Intel(R) Core(TM) i7-8700 CPU @ 3.20GHz)
desktop computer it comes out like this:

```text,name=cargo benchmark
Timer precision: 12 ns
fizzbuzz                                    fastest       │ slowest       │ median        │ mean          │ samples │ iters
├─ early_return_before_mod_bench            53.56 ms      │ 65.34 ms      │ 54.2 ms       │ 54.66 ms      │ 100     │ 100
├─ mod_then_match_bench                     56.45 ms      │ 60.22 ms      │ 57.23 ms      │ 57.38 ms      │ 100     │ 100
├─ naive_bench                              59.62 ms      │ 63.31 ms      │ 60.16 ms      │ 60.33 ms      │ 100     │ 100
├─ single_string_scan_bench                 59.59 ms      │ 64.17 ms      │ 60.3 ms       │ 60.48 ms      │ 100     │ 100
╰─ single_string_scan_early_fizzbuzz_bench  56.86 ms      │ 59.98 ms      │ 57.65 ms      │ 57.81 ms      │ 100     │ 100
```

Now, if you recall, the order in which these implementations had been thought
up in the video was:

1. `naive()`
2. `mod_then_match()`
3. `early_return_before_mod()`
4. `single_string_scan()`
5. `single_string_scan_early_fizzbuzz()`

The thought was that each iteration would hopefully be faster than the
previous one.

When I had first got the benchmarking done, I think that due to a combination
of cold CPU cache and some busy tasks on my desktop at the time (leading to
varying CPU time being available), I got quite an extreme result for
`single_string_scan()` and its variant `single_string_scan_early_fizzbuzz()`.
It came out about 12% _slower_ than the fastest of the other implementations,
and I rather excitedly told Andy about this.

On further checking this became a bit less dramatic, however, as can be seen
above. The mean time for `early_return_before_mod()` is 54.66 ms while the
mean time for `single_string_scan()` is 60.48 ms. That's about 10% slower.

This is consistently reproducible on my desktop and what it means is that **a
`for` loop iterating through `n_str.chars()` once is slower than doing
`n_str.contains(…)` twice!** That's the only difference between those two
implementations.

That last `single_string_scan()` version was thought to be a good place to
leave it, but in fact it ended up slower than most of the other versions. I
think it's a quite good real-world example of why not to try performance
tuning without checking.

It's also interesting to see what happens on a faster computer. I refreshed my
home fileserver's hardware within the last year so it is actually one of the
newest computers I own at home (AMD Ryzen 9 7900 12-Core Processor). Results
here look like:

```text,name=cargo benchmark
Timer precision: 10 ns
fizzbuzz                                    fastest       │ slowest       │ median        │ mean          │ samples │ iters
├─ early_return_before_mod_bench            30.6 ms       │ 42.58 ms      │ 30.93 ms      │ 32.37 ms      │ 100     │ 100
├─ mod_then_match_bench                     28.09 ms      │ 32.54 ms      │ 28.94 ms      │ 28.97 ms      │ 100     │ 100
├─ naive_bench                              29.44 ms      │ 31.55 ms      │ 30.11 ms      │ 30.14 ms      │ 100     │ 100
├─ single_string_scan_bench                 31.63 ms      │ 50.32 ms      │ 31.83 ms      │ 32.62 ms      │ 100     │ 100
╰─ single_string_scan_early_fizzbuzz_bench  31.28 ms      │ 32.26 ms      │ 31.53 ms      │ 31.54 ms      │ 100     │ 100
```

Here the results for all implementations are much closer. Possibly there is
nothing really to judge between them, performance-wise. Okay, the machines are
of different vintages, but they're both AMD64 running the same version of
Debian Linux and the Rust toolchain, and the workload is single-threaded.

On this newer, faster machine, `mod_then_match()` is consistently very
slightly better than every other implementation from the video. This was only
the second of five tries at improving this! It's also pleasing that it's one
of the nicest to look at. There really is no point in making it look
complicated if it has no bearing on the performance, right?

I suppose another way to look at it is that even the very straightforward list
of `if …` tests (`naive()`) is amongst the best performers. I will guess
that's because this is a pretty simple problem that the compiler ends up
optimising down to very similar machine code no matter which of these you
choose. I am not smart enough to prove that hypothesis.

## Relight my fire

At the beginning I'd sort of expected this outcome, though I _hadn't_ expected
`for c in n_str.chars()` to be noticeably worse than `n_str.contains(…)`. I'd
expected the results to be very close, and they are, except for that. It still
felt like a bit of an anticlimax though, and I wondered if there was anything
else I could learn.

This is a very noticeably CPU-bound task. My desktop's fans go crazy while
running `cargo benchmark` and I see that single-threaded process at 100% the
whole time. I wondered what a [flame graph] might look like.

[flame graph]: https://www.brendangregg.com/flamegraphs.html

This turns out to be really easy with Rust.

```bash
$ sudo apt install linux-perf
$ cargo install flamegraph
$ CARGO_PROFILE_RELEASE_DEBUG=true cargo flamegraph
```

{% admonition_body(type="info") %}

The `CARGO_PROFILE_RELEASE_DEBUG=true` causes the `release` build that `cargo`
will generate and run to still include debug symbols, which give the generated
graph more details. Normally `release` builds don't include debug symbols.

{% end  %}

That generates a `flamegraph.svg` file, which I do this to:

```bash
$ sed -i 's/eeeeee/111111/g; s/eeeeb0/111100/g' flamegraph.svg
```

because I have some vision issues and prefer a dark background.

Let's look at the `mod_then_match()` implementation.

It's a good idea to click on this to view it directly in your browser. The SVG
will provide detailed hover text for each function but that might be easier to
see when it's the full width of your browser, and that way you can also click
on a function to exclude all others.

{{ svgfigure(src="mod_then_match_flamegraph.svg", class="size-small center") }}

You see in there that `fzbz::mod_then_match` is using 70.06% of the CPU time.
So, not much to gain from improving anything outside of that function. Inside
it, we've got:

- `<T as alloc::string::ToString>::to_string` using 40.50% of CPU; then
- `core::ptr::drop_in_place<alloc::string::String>` using 8.77%; then
- `core::str::<impl str>::contains` using 11.61%

So 60.88% of the CPU time of the whole thing is spent converting numbers to
strings and then looking for characters inside them.

## It hurts when I do _this_

Yeah, so in this case it's not very hard to avoid turning these numbers into
strings.

```rust,name=src/lib.rs
pub fn only_using_mod(n: i32) -> Answer {
    let (buzzy, fizzy) = test_for_fives_and_sevens(n);

    let buzzy = buzzy || n % 5 == 0;
    let fizzy = fizzy || n % 7 == 0;

    match (buzzy, fizzy) {
        (true, true) => Answer::FizzBuzz,
        (true, _) => Answer::Buzz,
        (_, true) => Answer::Fizz,
        _ => Answer::Number(n),
    }
}

fn test_for_fives_and_sevens(mut n: i32) -> (bool, bool) {
    let mut five = false;
    let mut seven = false;

    // Doing `n % 10` separates off the last (right-most, least significant)
    // digit, then dividing by 10 lops off that digit and lets us consider
    // the next one. e.g. given `n = 4567`:
    // n % 10 = 7
    // seven = true
    // n / 10 = 456
    // n % 10 = 6
    // n / 10 = 45
    // n % 10 = 5
    // five = true
    // n / 10 = 4
    // n % 10 = 4
    // n / 10 = 0, stop there returning (true, true).
    while n > 0 {
        let digit = n % 10;

        match digit {
            5 => five = true,
            7 => seven = true,
            _ => {}
        };

        n /= 10;
    }

    (five, seven)
}

```

Plus another variant (`only_using_mod_with_early_return()`) that returns early
if both a 5 and a 7 have been seen.

### Slow desktop benchmark

```text,name=cargo benchmark
fizzbuzz                                    fastest       │ slowest       │ median        │ mean          │ samples │ iters
├─ early_return_before_mod_bench            53.3 ms       │ 56.87 ms      │ 53.89 ms      │ 54.11 ms      │ 100     │ 100
├─ mod_then_match_bench                     56.4 ms       │ 62.62 ms      │ 57.03 ms      │ 57.24 ms      │ 100     │ 100
├─ naive_bench                              59.34 ms      │ 62.13 ms      │ 60 ms         │ 60.12 ms      │ 100     │ 100
├─ only_using_mod_bench                     22.9 ms       │ 24.24 ms      │ 23.16 ms      │ 23.26 ms      │ 100     │ 100
├─ only_using_mod_with_early_return_bench   14.28 ms      │ 15.68 ms      │ 14.6 ms       │ 14.65 ms      │ 100     │ 100
├─ single_string_scan_bench                 59.32 ms      │ 62.9 ms       │ 60.15 ms      │ 60.25 ms      │ 100     │ 100
╰─ single_string_scan_early_fizzbuzz_bench  56.73 ms      │ 59.24 ms      │ 57.59 ms      │ 57.68 ms      │ 100     │ 100
```

### Faster server benchmark

```text,name=cargo benchmark
fizzbuzz                                    fastest       │ slowest       │ median        │ mean          │ samples │ iters
├─ early_return_before_mod_bench            30.6 ms       │ 42.58 ms      │ 30.93 ms      │ 32.37 ms      │ 100     │ 100
├─ mod_then_match_bench                     28.09 ms      │ 32.54 ms      │ 28.94 ms      │ 28.97 ms      │ 100     │ 100
├─ naive_bench                              29.44 ms      │ 31.55 ms      │ 30.11 ms      │ 30.14 ms      │ 100     │ 100
├─ only_using_mod_bench                     11.63 ms      │ 12.1 ms       │ 11.64 ms      │ 11.67 ms      │ 100     │ 100
├─ only_using_mod_with_early_return_bench   8.274 ms      │ 9.495 ms      │ 8.492 ms      │ 8.786 ms      │ 100     │ 100
├─ single_string_scan_bench                 31.63 ms      │ 50.32 ms      │ 31.83 ms      │ 32.62 ms      │ 100     │ 100
╰─ single_string_scan_early_fizzbuzz_bench  31.28 ms      │ 32.26 ms      │ 31.53 ms      │ 31.54 ms      │ 100     │ 100
```

### Flame graph for this version

{{ svgfigure(src="only_using_mod_with_early_return_flamegraph.svg", class="size-small center") }}

With that, `fizzbuzz_all()` uses 62,787,476 samples while
`test_for_fives_and_sevens_with_early_return()` uses 47.024,211 samples, so
just that function is still 74.89% of the CPU time of the meaningful part of
the whole program.

## Where to go next?

I'm not sure if this performance can be improved but I would like to improve
my knowledge of Divan.

I'd like to try benchmarking different end values for each implementation, so
for example to see how fast each can do up to 1,000, up to 10,000, up to
100,000 and so on. There might be some distributions that are faster than
others.

Once the numbers get long, is it worth trying to short circuit the "divisible
by both 5 and 7" case in order to sometimes avoid having to scan through the
whole number?

Maybe not but I'd like to work out how to do it anyway.

What if you spent some memory to cache the outcome of expensive calculations?
`fizzbuzz(i32::MAX)` is _always_ `Fizz` (in this variant)!

Then there is multithreading, but that is definitely for a later date!
