require "log"
require "csv"

module EvolveNet
  class Data
    Log = ::Log.for(self)

    @yrange : Int32
    @ymax : Int32
    @ymin : Int32

    property :normalized_outputs, :normalized_inputs, :labels, :inputs, :outputs

    def self.new_with_csv_input_target(csv_file_path, input_column_range, target_column)
      inputs = Array(Array(Float64)).new
      outputs = Array(Array(Float64)).new
      outputs_as_string = Array(String).new
      CSV.each_row(File.read(csv_file_path)) do |row|
        row_arr = Array(Float64).new
        row[input_column_range].each do |num|
          row_arr << num.to_f64
        end
        inputs << row_arr
        outputs_as_string << row[target_column]
      end
      d = Data.new(inputs, outputs)
      d.labels = outputs_as_string.uniq
      d.outputs = outputs_as_string.map { |string_output| d.array_for_label(string_output) }
      d.normalize_min_max
      d
    end

    def initialize(data : Array(Array(Array(Number))))
      inputs = data.map { |row| row[0].map { |col| col.as(Number) } }
      outputs = data.map { |row| row[1].map { |col| col.as(Number) } }
      initialize(inputs, outputs)
    end

    def initialize(raw_inputs : Array(Array(Float64)), raw_outputs : Array(Array(Float64)))
      inputs = raw_inputs.map { |row| row.map { |col| col.as(Number) } }
      outputs = raw_outputs.map { |row| row.map { |col| col.as(Number) } }
      initialize(inputs, outputs)
    end

    def initialize(@inputs : Array(Array(Number)), @outputs : Array(Array(Number)))
      @ymax = 1
      @ymin = 0
      @yrange = @ymax - @ymin

      @i_min = Array(Number).new
      @i_max = Array(Number).new
      @o_min = Array(Number).new
      @o_max = Array(Number).new

      @labels = Array(String).new # Array of possible data labels

      @normalized_inputs = Array(Array(Float64)).new
      @normalized_outputs = Array(Array(Float64)).new
    end

    def normalized_data
      arr = Array(Array(Array(Float64))).new
      @normalized_inputs.each_with_index do |_, i|
        arr << [@normalized_inputs[i], @normalized_outputs[i]]
      end
      arr
    end

    def raw_data
      arr = Array(Array(Array(Number))).new
      @inputs.each_with_index do |_, i|
        arr << [@inputs[i], @outputs[i]]
      end
      arr
    end

    def set_zero_to_average(cols = Array[Int32])
      avg = Array(Float64).new
      # Get inputs sum
      cols.each do |col|
        sum = 0_f64
        cnt = 0
        @inputs.each do |row|
          if row[col] != 0
            sum += row[col]
            cnt += 1
          end
        end
        avg << sum / cnt
      end

      # Set to average if zero
      @inputs.each do |row|
        cols.each_with_index do |col, idx|
          if row[col] == 0
            row[col] = avg[idx]
          end
        end
      end
    end

    def one_hot_encoder
    end

    def label_encoder
    end

    def ordinal_encoder
    end

    def normalize_min_max
      # Get inputs min-max
      @inputs.transpose.each { |a| @i_max << a.max; @i_min << a.min }

      # Get outputs min-max
      @outputs.transpose.each { |a| @o_max << a.max; @o_min << a.min }

      @inputs.each do |row|
        @normalized_inputs << normalize_inputs(row)
      end

      @outputs.each do |row|
        @normalized_outputs << normalize_outputs(row)
      end
    end

    def normalize_inputs(inputs : Array(Number))
      results = Array(Float64).new
      inputs.each_with_index do |input, i|
        results << normalize(input, @i_min[i], @i_max[i])
      end
      results
    end

    def normalize_outputs(outputs : Array(Number))
      results = Array(Float64).new
      outputs.each_with_index do |output, i|
        results << normalize(output, @o_min[i], @o_max[i])
      end
      results
    end

    def normalize(x, xmin, xmax)
      range = xmax - xmin
      adj_x = x.to_f64 - (xmin + @ymin)
      norm = (@yrange / range)
      value = adj_x * norm
      return 0.0 if value.nan?
      value
    end

    def denormalize_outputs(outputs : Array(Number))
      results = Array(Float64).new
      outputs.each_with_index do |output, i|
        results << denormalize(output, @o_min[i], @o_max[i])
      end
      results
    end

    def denormalize(x, xmin, xmax)
      range = xmax - xmin
      denorm = x.to_f64 * (range / @yrange)
      adj_x = @ymin + xmin
      value = denorm + adj_x
      return 0.0 if value.nan?
      value
    end

    # Splits the receiver in a TrainingData and a TestData object according to factor
    def split(factor)
      training_set_size = (raw_data.size * factor).to_i

      training_set = raw_data[0..training_set_size - 1]
      test_set = raw_data[training_set_size..raw_data.size - 1]

      Log.info { "Selected #{training_set.size} / #{raw_data.size} rows for training" }
      training_data = EvolveNet::TrainingData.new(training_set.map { |el| el[0] }, training_set.map { |el| el[1] })
      training_data.labels = @labels

      Log.info { "Selected #{test_set.size} / #{raw_data.size} rows for testing" }
      test_data = EvolveNet::TestData.new(test_set.map { |el| el[0] }, test_set.map { |el| el[1] })
      test_data.labels = @labels

      return training_data, test_data
    end

    # Receives an array of labels (String or Symbol) and sets them for this Data object
    def labels=(label_array)
      @labels = label_array.map(&.to_s)
      Log.info { "Labels are #{@labels.join(", ")}" } if self.class.name == "EvolveNet::Data"
    end

    # Takes a label as a String and returns the corresponding output array
    def array_for_label(a_label)
      @labels.map { |label| a_label == label ? 1.as(Number) : 0.as(Number) }
    end

    # Takes an output array of 0,1s and returns the corresponding label
    def label_for_array(an_array)
      index = an_array.index(an_array.max.to_f64)
      index ? @labels[index] : ""
    end

    def size
      @inputs.size
    end

    def to_onehot(data : Array(Array(Float64)), vector_size : Int32)
      data.each_with_index do |point, i|
        lbl = point.first.clone.to_i
        one_hot = Array(Float64).new(vector_size) { 0.0 }
        one_hot[lbl] = 1.0
        data[i] = one_hot
      end

      data
    end

    def confusion_matrix(model)
      tn = tp = fn = fp = ct = 0

      # determine accuracy
      @normalized_inputs.each_with_index do |value, idx|
        actual = model.run(value)
        expected = @normalized_outputs[idx]
        actual.each_with_index do |act, i|
          ct += 1
          if expected[i] > 0.5
            if actual[i] > 0.5
              tp += 1
            else
              fp += 1
            end
          else
            if actual[i] < 0.5
              tn += 1
            else
              fn += 1
            end
          end
        end
      end
      puts "Test size: #{@inputs.size}"
      puts "----------------------"
      puts "TN: #{tn} | FP: #{fp}"
      puts "----------------------"
      puts "FN: #{fn} | TP: #{tp}"
      puts "----------------------"
      puts "Accuracy: #{(tn + tp) / ct.to_f64}"
    end

    def raw_confusion_matrix(model)
      tn = tp = fn = fp = ct = 0

      # determine accuracy
      @inputs.each_with_index do |value, idx|
        actual = model.run(value)
        expected = @outputs[idx]
        actual.each_with_index do |act, idx|
          ct += 1
          if expected[idx] > 0.5
            if actual[idx] > 0.5
              tp += 1
            else
              fp += 1
            end
          else
            if actual[idx] < 0.5
              tn += 1
            else
              fn += 1
            end
          end
        end
      end

      puts "Test size: #{@inputs.size}"
      puts "----------------------"
      puts "TN: #{tn} | FP: #{fp}"
      puts "----------------------"
      puts "FN: #{fn} | TP: #{tp}"
      puts "----------------------"
      puts "Accuracy: #{(tn + tp).to_f64 / ct.to_f64}"
    end
  end
end
