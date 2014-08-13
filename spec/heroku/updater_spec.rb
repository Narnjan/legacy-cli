require "spec_helper"
require "heroku/updater"
require "heroku/version"

module Heroku
  describe Updater do

    describe('::latest_local_version') do
      it 'calculates the latest local version' do
        subject.latest_local_version.should == Heroku::VERSION
      end
    end

    describe('::compare_versions') do
      it 'calculates compare_versions' do
        subject.compare_versions('1.1.1', '1.1.1').should == 0

        subject.compare_versions('2.1.1', '1.1.1').should == 1
        subject.compare_versions('1.1.1', '2.1.1').should == -1

        subject.compare_versions('1.2.1', '1.1.1').should == 1
        subject.compare_versions('1.1.1', '1.2.1').should == -1

        subject.compare_versions('1.1.2', '1.1.1').should == 1
        subject.compare_versions('1.1.1', '1.1.2').should == -1

        subject.compare_versions('2.1.1', '1.2.1').should == 1
        subject.compare_versions('1.2.1', '2.1.1').should == -1

        subject.compare_versions('2.1.1', '1.1.2').should == 1
        subject.compare_versions('1.1.2', '2.1.1').should == -1

        subject.compare_versions('1.2.4', '1.2.3').should == 1
        subject.compare_versions('1.2.3', '1.2.4').should == -1

        subject.compare_versions('1.2.1', '1.2'  ).should == 1
        subject.compare_versions('1.2',   '1.2.1').should == -1

        subject.compare_versions('1.1.1.pre1', '1.1.1').should == 1
        subject.compare_versions('1.1.1', '1.1.1.pre1').should == -1

        subject.compare_versions('1.1.1.pre2', '1.1.1.pre1').should == 1
        subject.compare_versions('1.1.1.pre1', '1.1.1.pre2').should == -1
      end
    end

    shared_context 'with released version at 3.9.7' do
      before do
        Excon.stub({:host => 'assets.heroku.com', :path => '/heroku-client/VERSION'}, {:body => "3.9.7\n"})
      end
    end

    shared_context 'with local version at 3.9.6' do
      before do
        subject.stub(:latest_local_version).and_return('3.9.6')
      end
    end

    shared_context 'with local version at 3.9.7' do
      before do
        subject.stub(:latest_local_version).and_return('3.9.7')
      end
    end

    describe '::update' do
      include_context 'with released version at 3.9.7'

      describe 'non-beta' do
        before do
          zip = File.read(File.expand_path('../../fixtures/heroku-client-3.9.7.zip', __FILE__))
          hash = "615792e1f06800a6d744f518887b10c09aa914eab51d0f7fbbefd81a8a64af93"
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/download/zip'}, {:body => zip})
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/update/hash'}, {:body => "#{hash}\n"})
        end

        context 'with no update available' do
          include_context 'with local version at 3.9.7'

          it 'does not update' do
            expect(subject.update(false)).to be_false
          end
        end

        context 'with an update available' do
          include_context 'with local version at 3.9.6'

          it 'updates' do
            expect(subject.update(false)).to eq('3.9.7')
          end
        end
      end

      describe 'beta' do
        before do
          zip = File.read(File.expand_path('../../fixtures/heroku-client-3.9.7.zip', __FILE__))
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/download/beta-zip'}, {:body => zip})
        end

        context 'with no update available' do
          include_context 'with local version at 3.9.7'

          it 'still updates' do
            expect(subject.update(true)).to eq('3.9.7')
          end
        end
      end
    end
  end
end
