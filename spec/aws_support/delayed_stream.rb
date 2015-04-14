require 'timeout'

module AWSSupport
  class DelayedStream
    def initialize(delay_before_streaming, *streams)
      @streams = streams.flatten.select { |s| !s.nil? }
      if delay_before_streaming > 0
        @buffer = StringIO.new
        @thread = Thread.new do
          sleep delay_before_streaming
          start_streaming
        end
      end
    end

    attr_reader :streams
    attr_reader :buffer

    def start_streaming
      if @buffer
        buffer = @buffer
        @buffer = nil
        streams.each { |s| s.write(buffer.string) }
      end
    end

    def write(*args, &block)
      if buffer.nil?
        streams.each { |s| s.write(*args, &block) }
      else
        buffer.write(*args, &block)
      end
    end

    def close
      @streams = []
      @thread.kill if @thread
      @thread = nil
    end
  end
end
