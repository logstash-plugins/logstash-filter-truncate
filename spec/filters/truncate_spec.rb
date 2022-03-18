# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/truncate"
require "flores/random"
require "flores/rspec"

RSpec.configure do |config|
  Flores::RSpec.configure(config)
end


describe LogStash::Filters::Truncate do
  analyze_results

  context "with hash fields" do
    context "stress test" do
      let(:data) {
        {
          "foo" => { "bar" => Flores::Random.text(0..1000) },
          "one" => { "two" => { "three" => Flores::Random.text(0..1000) } },
          "baz" => Flores::Random.text(0..1000),
        }
      }
      let(:length) { Flores::Random.integer(0..1000) }
      subject { described_class.new("length_bytes" => length) }
      let(:event) { LogStash::Event.new(data) }

      before { subject.filter(event) }

      stress_it "should truncate all strings in the hash" do
        expect(event.get("[foo][bar]").bytesize).to be <= length
        expect(event.get("[one][two][three]").bytesize).to be <= length
        expect(event.get("baz").bytesize).to be <= length
      end
    end

    context "unit test" do

      let(:length) { 450 }
      subject { described_class.new("length_bytes" => length) }
      let(:event) { LogStash::Event.new(data) }

      context "fields exceeding length" do
        let(:data) {
          {
            "foo" => { "bar" => "a" * 500 },
            "one" => { "two" => { "three" => "b" * 600 } },
            "baz" => "c" * 700,
          }
        }

        it "should truncate all strings in the hash" do
          expect(subject).to receive(:filter_matched).once

          subject.filter(event)

          expect(event.get("[foo][bar]").bytesize).to be <= length
          expect(event.get("[one][two][three]").bytesize).to be <= length
          expect(event.get("baz").bytesize).to be <= length
        end
      end

      context "fields not exceeding length" do
        let(:data) {
          {
            "foo" => { "bar" =>"a" * 350 },
            "one" => { "two" => { "three" => "b" * 300 } },
            "baz" => "c" * 450,
          }
        }

        it "shouldn't truncate strings in the hash" do
          expect(subject).not_to receive(:filter_matched)
          foo_bar_prev = event.get("[foo][bar]").bytesize
          one_two_three_prev = event.get("[one][two][three]").bytesize
          baz_prev = event.get("baz").bytesize

          subject.filter(event)

          expect(event.get("[foo][bar]").bytesize).to eq foo_bar_prev
          expect(event.get("[one][two][three]").bytesize).to eq one_two_three_prev
          expect(event.get("baz").bytesize).to eq baz_prev
        end
      end
    end
  end

  context "with string fields" do
    let(:text) { Flores::Random.text(0..1000) }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("message" => text, "example" => text) }

    before do
      subject.filter(event)
    end

    stress_it "should truncate the requested field" do
      expect(event.get("example").bytesize).to be <= length
    end

    stress_it "should remain valid UTF-8" do
      expect(event.get("example")).to be_valid_encoding
    end

    it "should not modify `message`" do
      expect(event.get("message")).to be == text
    end
  end

  context "with non-string fields" do
    let(:number) { Flores::Random.integer(-500.. 500) }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("example" => number) }


    stress_it "should do nothing" do
      expect(event.get("example")).to be == number
      expect(subject).not_to receive(:filter_matched)
    end
  end

  context "with array fields" do
    let(:count) { Flores::Random.integer(0..20) }
    let(:list) { count.times.map { Flores::Random.text(0..1000) } }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("example" => list) }

    context "stress test" do
      before { subject.filter(event) }

      stress_it "should truncate all elements in a list" do
        count.times do |i|
          expect(event.get("[example][#{i}]").bytesize).to be <= length
        end
      end
    end

    context "containing elements greater than size" do
      let(:count) { 10 }
      let(:list) { count.times.map { "a" * 100) } }
      let(:length) { 50 }

      it "should truncate all elements" do
        expect(subject).to receive(:filter_matched).once

        subject.filter(event)

        count.times do |i|
          expect(event.get("[example][#{i}]").bytesize).to be <= length
        end
      end
    end

    context "containing elements with mixed sizes" do
      let(:count) { 10 }
      let(:list) { (count - 1).times.map { "a" * 20 } + ["b" * 100]}
      let(:length) { 50 }

      it "should truncate elements that exceed the length" do
        expect(subject).to receive(:filter_matched).once

        subject.filter(event)

        expect(event.get("[example][#{count - 1}]").bytesize).to be <= length
      end
    end
  end
end
