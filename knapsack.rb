class Bags
  attr_accessor :capacity, :weights, :values

  def initialize
    @capacity = 0
    @weights = Array.new # 重さ
    @values = Array.new # 価値
  end
end

$bags = Array.new

open('GA/testdata') do |file| #.read.split("\n")
  bag = Bags.new

  file.each do |line|
    if line.split(',').size == 1

      # 0 : 終端
      if line.to_i == 0
        $bags << bag
        bag = Bags.new
      else
        bag.capacity = line.to_i
      end

    else
      input = line.split(',').map(&:to_i)

      bag.weights << input[0]
      bag.values << input[1]
    end
  end
end

##動的計画法
#
#2.times do |n|
#
#  item = $bags[n].weights.size
#  capa = $bags[n].capacity
#
#  arr_w = []
#  arr_v = []
#
#  item.times do |i|
#    arr_w << $bags[n].weights[i]
#    arr_v << $bags[n].values[i]
#  end
#
#  puts 'bag' + n.to_s
#
#  max_cost = 0
#  dp = Hash.new
#  dp[0] = 0
#
#  item.times do |ind|
#    dp_tmp = dp.clone
#
#    dp.each do |key, value|
#      total_key = key + arr_w[ind]
#      total_value = value + arr_v[ind]
#
#      unless dp_tmp.has_key?(total_key)
#        dp_tmp[total_key] = total_value
#      end
#
#      if capa >= total_key && total_value > max_cost
#        max_cost = total_value
#      end
#    end
#
#    dp = dp_tmp
#  end
#
#  p max_cost
#
#end

2.times do |p|

  n = $bags[p].weights.size
  g = $bags[p].capacity
  r = [0] * (g+1)

  n.times do |i|
    v,w = $bags[p].values[i], $bags[p].weights[i]
    g.downto(w) do |ri|
      if r[ri] < r[ri-w]+v
        r[ri] = r[ri-w]+v
      end
    end
  end

  p r.max

end
