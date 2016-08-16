require 'matrix'

class Gene
  attr_accessor :rank, :ruled, :ruling
  attr_reader :chromosome, :fitness

  def initialize(length)
    @chromosome = []
    @rank = 1
    @ruled = 0
    @ruling = 0
    @fitness = Vector[]

    # 行：自分のグループ   列：比較対象のグループ番号（が含まれるインデックス = 距離）
    @group_tree = [ [[0],[1,6],[2,5],[3,4]],
                   [[1],[0,2],[3,6],[4,5]],
                   [[2],[1,3],[0,4],[5,6]],
                   [[3],[2,4],[1,5],[0,6]],
                   [[4],[3,5],[2,6],[0,1]],
                   [[5],[4,6],[0,3],[1,2]],
                   [[6],[0,5],[1,4],[2,3]] ]
  end

  def get_fitness(index=nil)
    if index.nil?
      @fitness
    else
      @fitness[index]
    end
  end

  def calc_fitness(matches,fitness)
    # group_distance >= 0
    fitness[0] = get_distance(matches)

    # scentPower_balance  > 0
    fitness[1] = 1.0 / fitness[1].uniq.size

    # volatile_balance  > 0
    fitness[2] = 1.0 / fitness[2].uniq.size

    @fitness = Vector[fitness[0],fitness[1],fitness[2]] #=> minimize
=begin
    # group_distance <= 1
    fitness[0] = 1.0 / (fitness[0]+1)

    # scentPower_balance  <= request.size
    fitness[1] = fitness[1].uniq.size

    # volatile_balance  <= request.size
    fitness[2] = fitness[2].uniq.size

    fitness #=> maximize
=end
  end

  def get_distance(matches)
    tmp_fitness = 0
    matches.each do |focus|
      matches.reject{|item| item==focus}.each do |other|
        tmp_fitness +=
            @group_tree[focus[:scent_group]].index {|path| path.include?(other[:scent_group])}
      end
    end
    tmp_fitness
  end
end

#遺伝子
#  大きさ : 目的とする効能(=request)の数
class Gene_a < Gene
  def initialize(length)
    super
    length.times do
      @chromosome << rand(Aroma.get.size)  # 入れる精油の番号
    end
    calc_fitness
  end

  def calc_fitness
    matches = []
    fitness = Array.new(3){[]}

    @chromosome.each do |bit|
      matches << Aroma.get[bit].clone
      fitness[1] << Aroma.get[bit][:scent_power]
      fitness[2] << Aroma.get[bit][:volatile]
    end

    super matches,fitness
  end
end

# 遺伝子配列
#   大きさ => データベース上の精油の数
#   配列   => [0,1,1,0,0,...]
#             index = 精油ID 入れる:1  / 入れない:0
class Gene_b < Gene
  def initialize(length)
    super
    length.times do
      @chromosome << rand(2)  # 入れる->1, 入れない->0
    end

    while @chromosome.inject(&:+) > 3 do
      index = rand(length)
      @chromosome[index] = 0
    end

    calc_fitness
  end

  def calc_fitness
    matches = []
    fitness = Array.new(3){[]}

    @chromosome.each_with_index do |bit, i|
      if bit == 1
        matches << Aroma.get[i].clone
        fitness[1] << Aroma.get[i][:scent_power]
        fitness[2] << Aroma.get[i][:volatile]
      end
    end

    super matches,fitness
  end
end
