require "log"

module EvolveNet
  class Organism
    Log = ::Log.for(self)

    property :networks
    @one_forth : Int32 = 1
    @two_forth : Int32 = 1
    @three_forth : Int32 = 1

    def initialize(network : Network, size : Int32 = 16)
      raise "size needs to be greater than 16" if size < 16
      @networks = Array(Network).new(size) { network.clone.randomize }
      @one_forth = (size * 0.25).to_i
      @two_forth = (@one_forth * 2).to_i
      @three_forth = (@one_forth * 3).to_i
    end

    def evolve(data : Array(Array(Array(Number))),
               generations : Int32 = 10000,
               error_threshold : Float64 = 0.0,
               log_each : Int32 = 1000)
      channel = Channel(Float64).new

      (0..generations).each do |gen|
        # evaluate
        @networks.each_with_index do |n, i|
          spawn do
            n.evaluate(data)
            channel.send(n.error)
          end
        end
        @networks.size.times { channel.receive }

        # sort networks - best to worst
        @networks.sort! { |a, b| a.error <=> b.error }

        # determine error
        error : Float64 = @networks[0].error
        if error <= error_threshold
          Log.info { "generation: #{gen} error: #{error}. below threshold. breaking." }
          break
        elsif gen % log_each == 0
          Log.info { "generation: #{gen} error: #{error}" }
        end

        # kill bottom quarter
        @networks = @networks[0...@three_forth]

        # clone top quarter
        @networks[0...@one_forth].each { |n| @networks << n.clone }

        # punctuate all but top by increasing magnitude
        @networks[1..3].each_with_index do |n, i|
          n.punctuate(i)
        end

        # mutate all but the best and punctuated networks
        (4...@networks.size).each { |n| @networks[n].mutate }
      end

      # return the best network
      @networks.sort! { |a, b| a.error <=> b.error }
      @networks.first
    end
  end
end
