module EvolveNet
  class Neuron
    property :activation, :bias, :synapses, :function

    def initialize(@function : Symbol)
      @activation = 0_f64
      @bias = 0_f64
      @synapses = Array(Synapse).new
    end

    def clone
      neuron = Neuron.new(@function)
      neuron.activation = @activation
      neuron.bias = @bias
      @synapses.each do |synapse|
        neuron.synapses << synapse.clone
      end
      neuron
    end

    def randomize
      @bias = rand(-1_f64..1_f64)
      @synapses.each { |s| s.randomize }
    end

    def mutate(mutation_rate : Float64)
      @bias += rand(-mutation_rate..mutation_rate)
      @synapses.each { |s| s.mutate(mutation_rate) }
    end

    def punctuate(pos : Int32)
      @bias = @bias.round(pos)
      @synapses.each { |s| s.punctuate(pos) }
    end

    def activate(value : Number)
      @activation = value
    end

    def activate(prev_layer : Layer)
      sum = @synapses.sum { |s| s.weight * prev_layer.neurons[s.neuron_index].activation }
      if @function == :none
        @activation = none(sum + @bias)
      elsif @function == :relu
        @activation = relu(sum + @bias)
      elsif @function == :sigmoid
        @activation = sigmoid(sum + @bias)
      elsif @function == :tanh
        @activation = tanh(sum + @bias)
      else
        raise "activation function #{@function} is not supported"
      end
    end

    def none(value : Number) : Float64
      value.to_f64
    end

    def relu(value : Number) : Float64
      value < 0 ? 0.to_f64 : value.to_f64
    end

    def sigmoid(value : Number) : Float64
      (1.0/(1.0 + Math::E**(-value))).to_f64
    end

    def tanh(value : Number) : Float64
      ((Math::E**(value) - Math::E**(-value))/(Math::E**(value) + Math::E**(-value))).to_f64
    end
  end
end