ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# concurrent-ruby >= 1.3.5 dropped its implicit `require 'logger'`, which Rails
# 7.0's ActiveSupport relies on at load time. Require it here (before rails loads,
# for both `rails` and `rake` entry points) so boot doesn't fail with
# "uninitialized constant ...::Logger". Removable after the Rails 7.1+ upgrade.
require 'logger'

require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
