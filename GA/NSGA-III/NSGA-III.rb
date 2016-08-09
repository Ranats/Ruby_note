require './Aroma'

# 調合する精油の数を制限しない
# 遺伝子配列
#   大きさ => データベース上の精油の数
#   配列   => [0,1,1,0,0,...]
#             index = 精油ID
#             入れる:1  / 入れない:0

# inject(:+) > request.size で致死遺伝子とする？
#   -> ランダムに一つ減らす

class Gene
  attr_accessor :fitness, :chromosome, :rank

  def initialize(length)
    @chromosome = []
    length.times do
      @chromosome << rand(2)  # 入れる->1, 入れない->0
    end
#    @score = Array.new(2, 0) #=> [score1,score2]
#    @rank = 1
    @fitness = calc_fitness
  end

  def get_fitness(index)
    fitness[index]
  end

  def calc_fitness
    @chromosome #=> [0,1,1,1,0,.....]

    # 行：自分のグループ   列：比較対象のグループ番号（が含まれるインデックス = 距離）
    group_tree = [ [[0],[1,6],[2,5],[3,4]],
                   [[1],[0,2],[3,6],[4,5]],
                   [[2],[1,3],[0,4],[5,6]],
                   [[3],[2,4],[1,5],[0,6]],
                   [[4],[3,5],[2,6],[0,1]],
                   [[5],[4,6],[0,3],[1,2]],
                   [[6],[0,5],[1,4],[2,3]] ]

    matches = []
    fitness = Array.new(3,0)

    @chromosome.each_with_index do |bit, i|
      if bit == 1
        matches << Aroma.get[i].clone
        fitness[1] += Aroma.get[i][:scent_power]
        fitness[2] += Aroma.get[i][:volatile]
      end
    end

    matches.each do |focus|
      matches.reject{|item| item==focus}.each do |other|
        fitness[0] +=
            group_tree[focus[:scent_group]].index {|path| path.include?(other[:scent_group])}
      end
    end

    # group_distance
    fitness[0]

    # scentPower_balance
    fitness[1] -= Aroma.get.size

    # volatile_balance
    fitness[2] -= Aroma.get.size

    fitness
  end
end

class NSGA_III

  def initialize(population)
    @population = population
    @generation = 0


  end

  def selection

  end

  def crossover(pair, position)
    child = Array.new(2,Gene.new(Aroma.get.size))
    child[0].chromosome = pair[0].chromosome.take(position) + pair[1].chromosome.drop(position)
    child[1].chromosome = pair[1].chromosome.take(position) + pair[0].chromosome.drop(position)
    child
  end

  def mutate(individual,position)
    individual.chromosome[position] == 1 ? 0 : 1
  end

  def next_generation(population)
    population = selection


    population
  end
end


