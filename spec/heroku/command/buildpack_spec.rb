require "spec_helper"
require "heroku/command/buildpack"

module Heroku::Command
  describe Buildpack do

    def stub_put(*buildpacks)
      Excon.stub({
        :method => :put,
        :path => "/apps/example/buildpack-installations",
        :body => {"updates" => buildpacks.map{|bp| {"buildpack" => bp}}}.to_json
      },
      {:status => 200})
    end

    def stub_get(*buildpacks)
      Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
      {
        :body => buildpacks.map.with_index { |bp, i|
          {
            "buildpack" => {
              "url" => bp
            },
            "ordinal" => i
          }
        },
        :status => 200
      })
    end

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar-14")

      Excon.stub({:method => :put, :path => "/apps/example/buildpack-installations"},
        {:status => 200})
      stub_get("https://github.com/heroku/heroku-buildpack-ruby")
    end

    after(:each) do
      Excon.stubs.shift
      Excon.stubs.shift
      api.delete_app("example")
    end

    describe "index" do
      it "displays the buildpack URL" do
        stderr, stdout = execute("buildpack")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example Buildpack URL
https://github.com/heroku/heroku-buildpack-ruby
        STDOUT
      end

      context "with no buildpack URL set" do
        before(:each) do
          Excon.stubs.shift
          stub_get
        end

        it "does not display a buildpack URL" do
          stderr, stdout = execute("buildpack")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
example has no Buildpack URL set.
          STDOUT
        end
      end
    end

    describe "set" do
      it "sets the buildpack URL" do
        stderr, stdout = execute("buildpack:set https://github.com/heroku/heroku-buildpack-ruby")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
        STDOUT
      end

      it "handles a missing buildpack URL arg" do
        stderr, stdout = execute("buildpack:set")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku buildpack:set BUILDPACK_URL.
 !    Must specify target buildpack URL.
        STDERR
        expect(stdout).to eq("")
      end

      it "sets the buildpack URL with index" do
        stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
        STDOUT
      end

      context "with one existing buildpack" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          stub_get("https://github.com/heroku/heroku-buildpack-java")
        end

        it "overwrites an existing buildpack URL at index" do
          stub_put(
            "https://github.com/heroku/heroku-buildpack-ruby"
          )
          stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end
      end

      context "with two existing buildpacks" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
        end

        it "overwrites an existing buildpack URL at index" do
          stub_put(
            "https://github.com/heroku/heroku-buildpack-ruby",
            "https://github.com/heroku/heroku-buildpack-nodejs"
          )
          stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-ruby
  2. https://github.com/heroku/heroku-buildpack-nodejs
Run `git push heroku master` to create a new release using these buildpacks.
          STDOUT
        end

        it "adds buildpack URL to the end of list" do
          stub_put(
            "https://github.com/heroku/heroku-buildpack-java",
            "https://github.com/heroku/heroku-buildpack-nodejs",
            "https://github.com/heroku/heroku-buildpack-ruby"
          )
          stderr, stdout = execute("buildpack:set -i 99 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-nodejs
  3. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
          STDOUT
        end
      end
    end

    describe "add" do
      context "with no buildpacks" do
        before(:each) do
          Excon.stubs.shift
          stub_get
        end

        it "adds the buildpack URL" do
          stderr, stdout = execute("buildpack:add https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end

        it "handles a missing buildpack URL arg" do
          stderr, stdout = execute("buildpack:add")
          expect(stderr).to eq <<-STDERR
 !    Usage: heroku buildpack:add BUILDPACK_URL.
 !    Must specify target buildpack URL.
          STDERR
          expect(stdout).to eq("")
        end

        it "adds the buildpack URL with index" do
          stderr, stdout = execute("buildpack:add -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end
      end

      context "with one existing buildpack" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          stub_get("https://github.com/heroku/heroku-buildpack-java")
        end

        it "inserts a buildpack URL at index" do
          stub_put("https://github.com/heroku/heroku-buildpack-ruby", "https://github.com/heroku/heroku-buildpack-java")
          stderr, stdout = execute("buildpack:add -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-ruby
  2. https://github.com/heroku/heroku-buildpack-java
Run `git push heroku master` to create a new release using these buildpacks.
          STDOUT
        end
      end
    end

    describe "clear" do
      it "clears the buildpack URL" do
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared. Next release on example will detect buildpack normally.
        STDOUT
      end

      it "clears and warns about buildpack URL config var" do
        execute("config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The BUILDPACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared.
        STDOUT
      end

      it "clears and warns about language pack URL config var" do
        execute("config:set LANGUAGE_PACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared.
        STDOUT
      end
    end
  end
end
