# Meslog

This project defines MESLOG data format, and provides the implementation of MESLOG data analyzer utility.

## What is MESLOG

MESLOG is designed for ease the pain of data summarization and analysis of experimental result.

## MESLOG data format

MESLOG data format is line-oriented text based format.
Actually any text files are qualified to be MESLOG files.
A MESLOG file is composed with (1) MESLOG data line and (2) normal line.
An example of an MESLOG data line is like:

    [MESLOG.sample]{"params":{"num_threads": 1},"data":{"flops": 1.0e9}}

`[MESLOG.sample]` is a mark that means this line might be special data line tagged by "sample".
After the mark, a string of JSON map object follows, which has two keys "params" and "data".
Bit more formal definition of MESLOG data line and normal line is:
  * Iff a string matches with `/\A\[MESLOG(\.[a-zA-Z0-9_-])?\]\Z/`, the string is "MESLOG header mark."
  * Iff a JSON map object has only two key "params", "data", the object is "MESLOG compliant JSON object."
  * Iff a line starts with a MESLOG header mark, followed by a string of a MESLOG compliant JSON object terminated by a newline character, the line is "MESLOG data line".
  * If a line is not a MESLOG data line, the line is "normal line".



Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/meslog`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'meslog'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install meslog

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/meslog. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

