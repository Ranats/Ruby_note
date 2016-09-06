require 'matrix'

class Gene
  attr_accessor :limit, :rank, :ruled, :ruling, :chromosome, :distance, :fitness

  def initialize
    @chromosome = []
    @rank = 1
    @ruled = 0
    @ruling = 0
    @fitness = Vector[]
    @distance = 0

    @limit = 12

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
    std_vec = Vector.elements(Array.new(3,@limit/3))
    # group_distance >= 0
    fitness[0] = get_distance(matches) / (29)

    # scentPower_balance  > 0
#    fitness[1] = 1.0 / fitness[1].uniq.size
    fitness[1] = std_vec - Vector[fitness[1].count(1),fitness[1].count(2),fitness[1].count(3)]
    fitness[1] = fitness[1].norm / (std_vec - Vector[0,0,@limit]).norm

    # volatile_balance  > 0
    #fitness[2] = 1.0 / fitness[2].uniq.size
    fitness[2] = std_vec - Vector[fitness[2].count(1),fitness[2].count(2),fitness[2].count(3)]
    fitness[2] = fitness[2].norm / (std_vec - Vector[0,0,@limit]).norm

    fitness.map!{|f| f.round(2)}

    @fitness = Vector[fitness[0],fitness[1],fitness[2]] #=> minimize

#    puts @fitness
 #   gets
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
    ret_fitness = 0.0
#    focus = matches.first
    matches.each do |focus|
      tmp_fitness = [0]
      matches.reject{|item| item==focus}.each do |other|
        tmp_fitness <<
            @group_tree[focus[:scent_group]].index {|path| path.include?(other[:scent_group])}
      end
#      p tmp_fitness
#      p tmp_fitness.inject(&:+)
      ret_fitness += tmp_fitness.inject(&:+)
    end
#    puts %(length:#{matches.length}, dist:#{ret_fitness})
#    gets
    ret_fitness / matches.length.to_f
  end

  def mutate(idx)
    idxs = @chromosome.map.with_index{|e,i| e == 1^@chromosome[idx] ? i : nil}.compact
    if idxs.length > 0
      @chromosome[idxs[rand(idxs.length)]] = @chromosome[idx]
      @chromosme[idx] = 1^@chromosome[idx]
    end
  end


end

#遺伝子
#  大きさ : 目的とする効能(=request)の数
class Gene_a < Gene
  def initialize(length)
    super()
    length.times do
      @chromosome << rand(Aroma.get.size)  # 入れる精油の番号
    end
    calc_fitness
    # 正規化?

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
  def initialize(length,request)
    super()
    length.times do
      @chromosome << rand(2)  # 入れる->1, 入れない->0
    end

    while @chromosome.inject(&:+) > @limit do
      index = rand(length)
      @chromosome[index] = 0
    end

    @chromosome.each_with_index do |bit,idx|
      if bit == 1
#        p Aroma.get[idx][:effect]
        request -= Aroma.get[idx][:effect]
      end
    end
    unless request.empty?
      initialize(length,request)
    end


    calc_fitness
  end

  def new_blank
    @chromosome = []
    @rank = 1
    @ruled = 0
    @ruling = 0
    @fitness = Vector[]
    @distance = 0

    @limit = 12

    # 行：自分のグループ   列：比較対象のグループ番号（が含まれるインデックス = 距離）
    @group_tree = [ [[0],[1,6],[2,5],[3,4]],
                    [[1],[0,2],[3,6],[4,5]],
                    [[2],[1,3],[0,4],[5,6]],
                    [[3],[2,4],[1,5],[0,6]],
                    [[4],[3,5],[2,6],[0,1]],
                    [[5],[4,6],[0,3],[1,2]],
                    [[6],[0,5],[1,4],[2,3]] ]
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
