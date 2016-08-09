require 'test/unit'

class Generator
  attr_reader :weights, :values, :capacity, :bags
  attr_writer :item

  def initialize(amount=100)
    @ITEM = amount
    @weights = Array.new(@ITEM) # 重さ
    @values = Array.new(@ITEM) # 価値
    @capacity = rand(@ITEM*25 .. @ITEM*30)
  end


  def bag2
    @bags = [self,Generator.new(@ITEM)]
    @bags.each(&:generate_items)
  end

  def bag1
    @bags = Array.new
    self.generate_items
    @bags << self
  end

  def generate_items
    [@weights, @values].each { |item| item.map! { |item| item = rand(10..100) } }
  end

  def write
    File.open('testdata','w') do |file|
      @bags.each do |bag|
        file.puts(bag.capacity)
        @ITEM.times do |i|
          file.puts("#{bag.weights[i]},#{bag.values[i]}")
        end
        file.puts 0
      end
    end
  end

end



if __FILE__ == $0

  begin
    puts 'bag1 : knapsack problem(bag:1)',
         'bag2 : knapsack problem(bag:2)'
    print 'select generation method: '

    method = gets.chomp

    unless Generator.method_defined?(method)
      raise "undefined method '#{method}'. try again."
    end
  rescue
    puts $!,""
    retry
  end

  print 'item amount : '

  amount = gets.to_i
  if amount == 0
    amount = 100
  end

  bag = Generator.new(amount)

  bag.send method

  bag.send "write"


end
