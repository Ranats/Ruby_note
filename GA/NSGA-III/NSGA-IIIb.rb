require './Aroma' # DB
require 'matrix'  # vectorを使うためのgem

=begin
遺伝子
  大きさ : 目的とする効能(=request)の数
=end
class Gene
  attr_accessor :fitness, :chromosome, :rank, :ruled, :ruling

  def initialize(length)
    @chromosome = []

    # length = request.size
    length.times do
      @chromosome << rand(Aroma.get.size)  # 入れる精油の番号
    end
    @rank = 1
    @fitness = calc_fitness
    @ruled = 0
    @ruling = 0
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
    fitness = Array.new(3)
    fitness[0] = 0
    fitness[1],fitness[2] = [],[]

    @chromosome.each do |bit|
      matches << Aroma.get[bit].clone
      fitness[1] << Aroma.get[bit][:scent_power]
      fitness[2] << Aroma.get[bit][:volatile]
    end

    matches.each do |focus|
      matches.reject{|item| item==focus}.each do |other|
        fitness[0] +=
            group_tree[focus[:scent_group]].index {|path| path.include?(other[:scent_group])}
      end
    end

    # group_distance >= 0
    fitness[0] = fitness[0]

    # scentPower_balance  > 0
    fitness[1] = 1.0 / fitness[1].uniq.size

    # volatile_balance  > 0
    fitness[2] = 1.0 / fitness[2].uniq.size

    Vector[fitness[0],fitness[1],fitness[2]] #=> minimize

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
end

class NSGA_III

  def initialize(population)
    @population = population
    @generation = 0

    @pareto = []

    # 減少率
    @reduction_rate = population.size / 10

  end

  def selection

  end

  # 高速非優越ソート ... ランク付け
  #    高速非優越ソートとは，パレート最適解
  #    の支配関係によって各個体にランクと呼ばれる評価基準
  #    与える操作である．ランクは最高が1となり，数字が大き
  #    くなるほど評価を下げることになる．まず，各個体に対
  #    して，支配している個体とされている個体を同時に数え
  #    る．次に，支配されている個体数０の個体をランク１と
  #    する．ランク１の個体のみを次の探索に保存し，保存さ
  #    れた各個体が支配している個体に対して，支配されてい
  #    る数を１ずつ引くことになる．そして，次のフロントを
  #    探索するために，ランク１の個体を除外し，これまでと
  #    同様なプロセスを繰り返すことになる．この操作を全個
  #    体にランクが与えられるまで繰り返すことで，順位付け
  #    を行う操作
  # つまりランク1をつけたら、それらの個体は除外して次のランクをつける。みたいな？
  def f_non_dominated_sort(population)
    population.each do |pop|
      pop.ruled = population.count{ |other| other.fitness.norm < pop.fitness.norm}
#      pop.ruling = population.count{ |other|  pop.fitness.norm < other.fitness.norm}
    end

    # ruledの配列 をソート したものをuniqした配列でeach
    population.sort_by{|p| p.ruled}.collect{|p| p.ruled}.uniq.each_with_index  do |r,current_rank|
      population.map{|pop| pop.rank = current_rank if pop.ruled == r}
    end

    puts "fitness.norm : ruled_individual : rank"
    population.sort_by{|p| p.ruled }.each do |s|
      puts "#{s.fitness.norm} : #{s.ruled} : #{s.rank}"
    end
  end

  def crowding_sort(population)
    # ソートされたものを返す

    return population
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

  def next_generation

    # Step.2 探索母集団Q_tの評価を行う
    @population.each {|pop| pop.calc_fitness}

    # Step.3 アーカイブ集団(=パレート集合?)と探索母集団を組み合わせて R_t = P_t U Q_t を生成する。
    search_population = @pareto.clone + @population.clone

    # R_t に対して非優越ソートを行い、
    f_non_dominated_sort(search_population)
    # 全体をフロント毎(ランク毎)に分類する：F_i, i=1, 2, ...




#    search_population.sort_by{|p| p.rank }.each do |s|
#      p s.rank
#    end

    # Step 4 新たなアーカイブ母集団 Pt+1 = φ を生成．変数 i = 1 とする．
    # |Pt+1| + |Fi| < N(=個体数 - d(減少率)) を満たすまで，Pt+1 = Pt+1 ∪ Fi と i = i + 1 を実行．
    i = 1
    @pareto = []
    while @pareto.size < @population.size - @reduction_rate
      @pareto << search_population.select{|pop| pop.rank == 1}
      i += 1
    end

    # Step 5 混雑度ソート (Crowding-sort) を実行し，Fi の中で最も多様性に優れた（混雑距離の大きい）
    # 個体 N − |Pt+1| 個を Pt+1 に加える．

    @pareto += crowding_sort(search_population).take(@reduction_rate)

    # Step 6 終了条件を満たしていれば，終了する．
    # Step 7 Pt+1 を基に，混雑度トーナメント選択により新たな探索母集団 Qt+1 を生成する．
    # Step 8 Qt+1 に対して遺伝的操作（交叉，突然変異）を行う．t = t + 1 をとし，Step 2 に戻る．

    population = selection



    population
  end
end

