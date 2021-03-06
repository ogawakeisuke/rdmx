require 'narray'
module Rdmx
  class Layers < Array
    attr_accessor :universe, :compositor

    def initialize count, universe
      self.universe = universe
      self.compositor = :addition
      super(count){|i|Rdmx::Layer.new(self)}
    end

    def composite!
      universe.values.replace composite
    end

    def calibrate *calibrations
      calibrations *= universe.values.size / calibrations.size
      calibrations += calibrations[0...(universe.values.size % calibrations.size)]
      @calibrations = NArray.to_na calibrations
    end

    def composite_base
      NArray.float(universe.values.size)
    end

    # See http://en.wikipedia.org/wiki/Alpha_compositing#Alpha_blending
    def alpha_compositor
      inject(composite_base) do |composite, layer|
        ((layer.alpha - 1).abs * composite) + (layer.alpha * layer.values)
      end
    end

    def addition_compositor
      inject(composite_base) do |composite, layer|
        composite + layer.values
      end
    end

    def composite
      composite = send "#{self.compositor}_compositor"
      composite *= @calibrations if @calibrations
      composite[composite.gt 255] = 255
      composite[composite.lt 0] = 0
      composite.to_i.to_a
    end

    def add_layer_args *args
      if args.empty? || (args.size == 1 && args.first.is_a?(Integer))
        num = args.pop || 1
        args = num.times.map{Rdmx::Layer.new(self)}
      end
      args
    end

    def push *obj
      super(*add_layer_args(*obj))
    end

    def unshift *obj
      super(*add_layer_args(*obj))
    end
  end

  class Layer
    attr_accessor :values, :fixtures, :parent, :alpha

    def initialize parent
      self.parent = parent
      self.values = NArray.float parent.universe.values.size
      self.alpha = NArray.float parent.universe.values.size
      self.alpha[] = 1.0
      self.fixtures = Rdmx::Universe::FixtureArray.new self,
        parent.universe.fixture_class
    end

    def [] *args
      values.send :[], *args
    end

    def []= *args
      values.send :[]=, *args
    end
  end
end
