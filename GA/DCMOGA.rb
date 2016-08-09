require 'gnuplot'
require 'benchmark'
require 'parallel'

class Bags
  attr_accessor :capacity, :weights, :values

  def initialize
    @capacity = 0
    @weights = Array.new # 重さ
    @values = Array.new # 価値
  end
end

class Gene
  attr_accessor :score, :chromosome, :rank

  def initialize(length)
    @chromosome = []
    length.times do
      @chromosome << rand(2)
    end
    @score = Array.new(2, 0) #=> [score1,score2]
    @rank = 1
  end

  def evaluate
    $bags.each_with_index do |bag, index|
      value_sum = 0
      weight_sum = 0
      @chromosome.each_with_index do |locas, index|
        if locas == 1
          weight_sum += bag.weights[index]
          value_sum += bag.values[index]
        end
      end

      # キャパ超えてたらスコアを0に。
      if weight_sum > bag.capacity
        @score[index] = 0
      else
        @score[index] = value_sum
      end
    end
  end

end

class GA
  attr_accessor :genes, :generation, :pareto

  # GAオペレータ
  def initialize(population: 4, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @population = population
    @crossover_rate = crossover_rate
    @mutation_rate = mutation_rate
    @generation = 0

    @genes = create_genes

    @pareto = []

  end

  def create_genes
    @genes = []
    while @genes.size < @population
      gene = Gene.new($item_size)

      gene.evaluate

      # スコアが0だったら(=キャパ超えてたら)個体として追加しない。
      if gene.score.min > 0
        @genes << gene
      end
    end

    return @genes
  end

  def roulette_select(f,total)
    ret = []

    # 個体数ぶんだけルーレット選択で親を選ぶ→ランダムに2個体ずつ選んで交叉

    @population.times do |i|
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      @genes.size.times do |j|
        roulette_value += f[j]
        if roulette_value > roulette_cf
          roulette_num = j
          break
        end
      end


      ret << @genes[roulette_num]
    end
    return ret
  end

  def roulette_crossover(f,total)
    ret = []

    # or 2個体選ぶ→交叉→2個体選ぶ→．．．
    # 同じ個体を親として選ばない
    parent = @genes.map(&:dup)
    f_d =  Marshal.load(Marshal.dump(f))
#    puts "f_d.size : #{f_d.size}"

    2.times do |i|
#      p f_d.size
#      p parent.size
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      parent.size.times do |j|
        roulette_value += f_d[j]
        if roulette_value > roulette_cf
          roulette_num = j
          break
        end
      end
      ret << parent[roulette_num]

#      puts "roulette_num: #{roulette_num}"
#      puts "f_d.size : #{f_d.size}"
#      puts "f_d"

      total -= 1.0 / f_d[roulette_num]
      parent.delete_at(roulette_num)
      f_d.delete_at(roulette_num)

#      puts "f_d.size after : #{f_d.size}"
#      puts "f.size : #{f.size}"
    end

    return ret
  end

  # 一点交叉
  def crossover(parents)
    length = parents[0].chromosome.size
    child = Marshal.load(Marshal.dump(parents))

    start_id = rand(length)

    child[0].chromosome[start_id...length] = parents[1].chromosome[start_id...length]
    child[1].chromosome[start_id...length] = parents[0].chromosome[start_id...length]

    return child

  end

  def mutation(gene, rate)
    if rand < rate
      p = rand($item_size)
      gene.chromosome[p] = (gene.chromosome[p] == 1) ? 0 : 1
    end
    gene
  end

  # 評価値が0 = 許容量を超えている場合、荷物をランダムに減らす
  def check(genes)
    genes.map(&:evaluate)
    genes.each do |gene|
      while gene.score.min == 0
        gene.chromosome[rand($item_size)] = 0
        gene.evaluate
      end
    end
  end

end

class MOGA < GA

  # DCMOGA提案手法
  # ランキング法でランクつけてルーレット選択で個体を選択する。
  # 選択された親個体と交叉させた子個体をすべて次世代に引き継ぐ
  # → それによって個体数が規定値より多ければ、シェアリングによって適合度を与えてルーレット選択?

  # Fonsecaらのランキング法 → ランク1の個体のみを選択するパレート保存戦略
  # → ランクに基づくルーレット選択

  # 個体群にランク1の個体ばっかりになる可能性?
  #   → uniqしちゃう?

  # rank_x = 1 + n_x

  # なんか良いアルゴリズム無いかな
  def ranking
    @genes.each do |gene|
      gene.rank = 1
      @genes.each do |gene2|
        if gene == gene2
          next
        end
        if gene2.score[0] >= gene.score[0] && gene2.score[1] >= gene.score[1]
          gene.rank += 1
        end
      end
    end
    @genes.sort_by!{|gene| gene.rank}
  end

  # ルーレット選択
  # ランクの高いもの=数値の小さいものを優先する => 逆数取る
=begin
  # 重複した親との交叉を許さない
  def roulette_select(parent, total)
    pair = []

#    parent = Marshal.load(Marshal.dump(@genes))
#    parent = @genes.map(&:dup)
#    total = parent.inject(0) { |total, gene| total + 1.0/gene.rank } #=>  これもポリモーフィズムで

    p parent.object_id

# ペア2つを作る
    2.times do
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      parent.size.times do |j|
        roulette_value += 1.0/parent[j].rank  #=> 1.0/@genes[j].rank と @genes[j].score[i] をStateパターンでやって一つのメソッドにする。GA親クラスの。
#        p rulet_value
        if roulette_value > roulette_cf
          roulette_num = j
#          p rulet_num
          break
        end
      end
      pair << parent[roulette_num]
      total -= 1.0/parent[roulette_num].rank
      # 親に選択したやつを除き、もう一方の親を選択する。
      parent.delete_at(roulette_num)
    end

    return pair

  end
=end

  def archive(genes)
    @pareto += genes.map(&:dup)#.select{|gene| gene.rank == 1}
    @pareto.each do |gene|
      gene.rank = 1
      @pareto.each do |gene2|
        if gene == gene2
          next
        end
        if gene2.score[0] > gene.score[0] && gene2.score[1] > gene.score[1]
          gene.rank += 1
        end
      end
    end

#    @pareto.sort_by!{|gene| gene.rank}
#    p @pareto[0,10]
#    @pareto.delete_if{|gene| gene.rank > 1}

    return @pareto
  end

  def sharing
    #niche count
    #=> 混み合ってると値が大きくなる
    m = []

    x_i = @pareto.sort_by{|gene| gene.score[0]} # .min / .max
    x_j = @pareto.sort_by{|gene| gene.score[1]} # .min / .max
    max_d = Math.sqrt( (x_i.first.score[0] - x_i.last.score[0]) ** 2  +
            (x_j.first.score[1] - x_i.last.score[1]) ** 2 )

    sig_share = max_d / @population

    @pareto.each_with_index do |x,i|
      m[i] = 0
      @pareto.each do |y|
        d = Math.sqrt( (x.score[0] - y.score[0]) ** 2 +
                           (x.score[1] - y.score[1]) ** 2 )
        m[i] += [0, 1 - (d / sig_share)].max
      end
    end

    total = 0
    m.each do |niche|
      total += 1.0 / niche
    end

    ret = []

    20.times do |i|
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      @pareto.size.times do |j|
        if m[j] > 0
          roulette_value += 1.0 / m[j]
        end
        if roulette_value > roulette_cf
          roulette_num = j
          break
        end
      end
      ret << @pareto[roulette_num]
    end

    @pareto = ret
  end

  def start

    if @genes.all? {|gene| gene.chromosome == @genes[0].chromosome}
      return -1
    end


    @generation += 1

#    puts "generation : #{@generation}"
#    puts "gene size : #{@genes.size}"
#    puts "pareto size : #{@pareto.size}"

    children = []

    # elite
#    children = @genes.select{|gene| gene.rank == 1}

    # パレートアーカイブから加える
#    children += @pareto.uniq

      # roulette
      total = 0
      f = []
      @genes.each do |gene|
        total += 1.0 / gene.rank
        f << 1.0 / gene.rank
      end

#    puts "genesize : #{@genes.size}"
#    puts "f.size : #{f.size}"


    # 個体数ぶんだけルーレット選択で親を選ぶ→ランダムに2個体ずつ選んで交叉
#    parent = roulette_select(f,total)

      # 交叉
#      parent.shuffle.each_cons(2) do |pair|
#        children += crossover(pair).map{|child| mutation(child, @mutation_rate)}
#      end

#    puts "gene size : #{@genes.size}"
#    puts "f_read default size : #{f.size}"

    # 2個体選ぶ→交叉→2個体選ぶ→交叉→．．． 2つの親は同じ個体を選ばない
    (@population/2).times do |i|
#      puts "f_read size : #{f.size}"
      parent = roulette_crossover(f,total)
      children += crossover(parent).map {|child| mutation(child, @mutation_rate)}
    end

#    puts "f_read after size : #{f.size}"

    check(children)


    # 選択数を一定にして超えた分をシェアリングに掛けて個体数を調整する?

#    result = Benchmark.realtime do
#      ranking
#    end

#    puts "children size before pop #{children.size}"

#    self.archive
    children = self.archive(children).map(&:dup)
    children.sort_by!{|gene| gene.rank}
#    p children
    children.pop(children.size - @population)

#    puts "children size after pop #{children.size}"

    @genes = children

#    puts "genes size final : #{@genes.size}"
#    p @generation
#    puts "\npareto size : #{@pareto.size}"
#    p @pareto
#    gets

    @pareto.uniq!
    @pareto.delete_if{|gene| gene.rank > 1}

#    puts "\npareto deleted size : #{@pareto.size}"
#    p @pareto
#    gets
#    puts "genes size final : #{@genes.size}"

    # 個体数を超える場合、シェアリングにより適合度を与えてルーレット選択

    if @pareto.size > 500
      sharing
    end


  end

end

class SGA < GA
  def sort(genes,i)
#    @genes.sort! { |a, b| a.score[i] <=> b.score[i] }.reverse!
    genes.sort_by!{|gene| gene.score[i]}.reverse!
  end

=begin
  # ルーレット選択
  def roulette_select(i)
    pair = []

#    parent = Marshal.load(Marshal.dump(@genes))
    parent = @genes.map(&:dup)

    # ペア2つを作る
    2.times do
      total ||= parent.inject(0) { |total, score| total + score.score[i] }
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      parent.size.times do |j|
        roulette_value += parent[j].score[i]
#        p rulet_value
        if roulette_value > roulette_cf
          roulette_num = j
#          p rulet_num
          break
        end
      end
      pair << parent[roulette_num]
      parent.delete_at(roulette_num)
    end

    return pair
    end
=end

  def archive(genes, i)
#    puts "pareto : "
#    p @pareto
#    puts "\ngenes : "
#    p genes
#    puts "pareto : "
#    p @pareto

#    @pareto = [@genes[0],genes].max_by{|gene| gene.score[i]}
    @genes[0] = [@genes[0],genes].max_by{|gene| gene.score[i]}

#    puts "pareto : "
#    p @pareto

#    gets

    return @pareto

    @pareto += genes.map(&:dup)
    @pareto.each do |gene|
      gene.rank = 1
      @pareto.each do |gene2|
        if gene == gene2
          next
        end
        if gene2.score[0] >= gene.score[0] && gene2.score[1] >= gene.score[1]
          gene.rank += 1
        end
      end
    end

#    puts "\npareto_after : "
#    p @pareto

    return @pareto
#    @pareto.delete_if{|gene| gene.rank > 1}
  end

  def sharing
    #niche count
    #=> 混み合ってると値が大きくなる
    m = []

    x_i = @pareto.sort_by{|gene| gene.score[0]} # .min / .max
    x_j = @pareto.sort_by{|gene| gene.score[1]} # .min / .max
    max_d = Math.sqrt( (x_i.first.score[0] - x_i.last.score[0]) ** 2  +
                           (x_j.first.score[1] - x_i.last.score[1]) ** 2 )

    sig_share = max_d / @population

    @pareto.each_with_index do |x,i|
      m[i] = 0
      @pareto.each do |y|
        d = Math.sqrt( (x.score[0] - y.score[0]) ** 2 +
                           (x.score[1] - y.score[1]) ** 2 )
        m[i] += [0, 1 - (d / sig_share)].max
      end
    end

    total = 0
    m.each do |niche|
      total += 1.0 / niche
    end

    ret = []

    20.times do |i|
      roulette_cf = rand(10000) / 10000.0 * total
      roulette_num = 0
      roulette_value = 0
      @pareto.size.times do |j|
        if m[j] > 0
          roulette_value += 1.0 / m[j]
        end
        if roulette_value > roulette_cf
          roulette_num = j
          break
        end
      end
      ret << @pareto[roulette_num]
    end

    @pareto = ret
  end

  def start(num)

    if @genes.all? {|gene| gene.chromosome == @genes[0].chromosome}
      return -1
    end

    @generation += 1

    children = []

    # elite << @genes[1]
#    children << @genes[0]
#    children += @pareto

    children << @genes[0].dup

    # roulette
    total = 0
    f = []
    @genes.each do |gene|
      total += gene.score[num]
      f << gene.score[num]
    end

#    puts "genesize : #{@genes.size}"
#    puts "f.size : #{f.size}"

    # 個体数ぶんだけルーレット選択で親を選ぶ→ランダムに2個体ずつ選んで交叉
#    parent = roulette_select(f,total)
    # 交叉
#        parent.shuffle.each_cons(2) do |pair|
#      children += crossover(pair).map {|child| mutation(child, @mutation_rate)}
#     end

    # 2個体選ぶ→交叉→2個体選ぶ→交叉→．．． 2つの親は同じ個体を選ばない
    (@population/2).times do |i|
      parent = roulette_crossover(f,total)
      children += crossover(parent).map {|child| mutation(child, @mutation_rate)}
    end


#    p children

    check(children)

#    children = self.archive(children).map(&:dup)
    self.sort(children,num)
    children.pop(children.size - @population)

    # 次世代へ
    @genes = children

#    puts "\npareto_archived : "
 #   p @pareto

#    @pareto.uniq!
#    @pareto.delete_if{|gene| gene.rank > 1}

#    puts "\npareto_deleted : "
 #   p @pareto

#    if @pareto.size > 100
#      sharing
#    end

#    @pareto = @genes[0].dup
#    self.archive

#    yield(@generation, @genes, )
#    max = @genes.max {|a, b| a.score[num] <=> b.score[num]}

#    p "max:#{max.score[num]}"
#    p @genes
#    p @genes.size
#    n = gets
  end
end

# 遺伝子長 = 荷物(item)数

class DCMOGA
  attr_accessor :moga, :sga1, :sga2, :pareto

  def initialize(end_of_eval: 20000000, to_migrate: 4000, population: 100, problems: Array.new, time:0)
    @time = time
    @generation = 1
    @to_migrate = to_migrate
    @end_of_eval = population * 20000
#    @end_of_eval = population * 20J
    @evaluated = 0
    @to_migrate_moga = population * 10 #to_migrate / population
    @to_migrate_sga = Array.new(2,population * 10) #Array.new(2, to_migrate / 100)
#    @to_migrate_sga = Array.new(2,to_migrate)

    @limit = population * 30

    @change_rate = 100


    @moga = MOGA.new(population: population, crossover_rate: 1.0, mutation_rate: 0.01)

    @moga.ranking


    # 1世代目のMOGAの個体群
    #    p moga.genes
    #    @moga.genes.each do |gene|
    #      p gene
    #    end

    @sga1 = SGA.new(population: 10, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
#   @sga1 = SGA.new(population: 100, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @sga1.sort(@sga1.genes,0)
#    @sga1.pareto = @sga1.genes[0]
    @sga2 = SGA.new(population: 10, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
#    @sga2 = SGA.new(population: 100, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @sga2.sort(@sga2.genes,1)
#    @sga2.pareto = @sga2.genes[0]

    @pareto = []
#    self.archive

#    [@sga1,@sga2].each do |sga|
#      sga.genes.each do |gene|
#        p gene
#      end
#    end
  end


  # 移住
  #   I_S = SGA個体群の最適解
  #   I_M = MOGA個体群のF_iの最良値を持つ最適解
  #   を交換する
  def migration

    # 移住は移動？それともコピー？
    i_m = Array.new(2)
    i_s = [@sga1.genes.shift,@sga2.genes.shift]

    2.times do |i|
      i_m[i] = @moga.genes.sort_by!{|gene| gene.score[i]}.reverse!.shift
    end

    i_s.each_with_index do |s,index|
      if s.score[index] > i_m[index].score[index]
        @to_migrate_sga[index] -= @change_rate
        @to_migrate_moga += @change_rate
      else
        @to_migrate_sga[index] += @change_rate
        @to_migrate_moga -= @change_rate
      end
    end

    # 移住間隔が肥大化していたのを防ぐ

    if @to_migrate_moga < 100
      @to_migrate_moga = 100
    end
    2.times do |i|
      if @to_migrate_sga[i] < 100
        @to_migrate_sga[i] = 100
      end
    end

    if @to_migrate_moga > @limit
      @to_migrate_moga = @limit
    end
    2.times do |i|
      if @to_migrate_sga[i] > @limit
        @to_migrate_sga[i] = @limit
      end
    end


    @moga.genes += i_s
    @sga1.genes << i_m[0]
    @sga2.genes << i_m[1]

    @moga.ranking
    @sga1.sort(@sga1.genes,0)
    @sga2.sort(@sga2.genes,1)

    # パレートアーカイブを更新
    @moga.archive(i_s)
    @moga.pareto.delete_if{|gene| gene.rank > 1}

    @sga1.archive(i_m[0],0)
    @sga2.archive(i_m[1],1)
    @pareto.delete_if{|gene| gene.rank > 1}


  end

  # パレートアーカイブ
  def archive
    @pareto += @moga.pareto + @sga1.pareto + @sga2.pareto
    @pareto.each do |gene|
      gene.rank = 1
      @pareto.each do |gene2|
        if gene == gene2
          next
        end
        if gene2.score[0] > gene.score[0] && gene2.score[1] > gene.score[1]
          gene.rank += 1
        end
      end
    end

    #uniq
    @pareto.uniq!{|gene| gene.chromosome}
#    @pareto.uniq!
    @pareto.delete_if{|gene| gene.rank > 2}
  end

  def start
    while @evaluated < @end_of_eval
      # MOGA loop
#      total = @moga.inject(0){ |total, gene| total + 1.0/gene.rank}
      while @moga.generation < @to_migrate_moga
#        puts "times : #{@time}"
        if @moga.start == -1
          break
        end
        #        puts "moga generation : " + @moga.generation.to_s
      end

      puts "moga finish."
      max1_m = @moga.genes.max_by{|gene| gene.score[0]}.score[0]
      max2_m = @moga.genes.max_by{|gene| gene.score[1]}.score[1]
      puts "max1 : #{max1_m}"
      puts "max2 : #{max2_m}"

      # SGAs loop
      [@sga1, @sga2].each_with_index do |sga, index|
        while sga.generation < @to_migrate_sga[index]
#          puts 'generation  : ' + sga.generation.to_s
          if sga.start(index) == -1
            break
          end
#          puts 'sga' + index.to_s
#          puts 'max fitness : ' + sga.genes[0].score[index].to_s
#          sga.genes.each do |gene|
#            print gene.chromosome, gene.score[index], "\n"
#          end

#          break if gets =~ /x/

#          yield(index, sga.generation, sga.genes[0].score[index])
        end
      end

      puts "sga finish."
      smax1 = @sga1.genes.max_by{|gene| gene.score[0]}.score[0]
      smax2 = @sga2.genes.max_by{|gene| gene.score[1]}.score[1]

      puts "max1 : #{smax1}"
      puts "max2 : #{smax2}"

      puts "moga > sga1 : #{max1_m > smax1}"
      puts "moga > sga1 : #{max2_m > smax2}"


      # print genes
#      [@sga1,@sga2].each do |sga|
#        sga.genes.each do |gene|
#          p gene
#        end
#      end

      # パレートアーカイブ
      self.archive

      self.migration
      puts "moga_migrate: " + @to_migrate_moga.to_s
      puts "sga1_migrate: " + @to_migrate_sga[0].to_s
      puts "sga2_migrate: " + @to_migrate_sga[1].to_s

      # if @moga.genes[0].score[0] > @sga1.genes[0].score
      #   @to_migrate_moga -= @change_rate
      #   @to_migrate_sga[0] += @change_rate
      # else
      #   @to_migrate_moga += @change_rate
      #   @to_migrate_sga[0] -= @change_rate
      # end

      @evaluated += [@moga.generation, @sga1.generation, @sga2.generation].inject(:+)

      puts "evaluated : " + @evaluated.to_s + "\n"

      @moga.generation = @sga1.generation = @sga2.generation = 0
      yield(@evaluated,@moga.genes[0].score, @to_migrate_moga, @to_migrate_sga)
      @generation += 1
    end
  end
end


def plot(index, x, y, max)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "SGA 最良個体の推移 max: #{max[0]}, #{max[1]}"

      plot.ylabel 'value'
      plot.xlabel 'generation'
      plot.terminal 'pngcairo size 600,600'
      plot.output "glaph/elite/SGA_#{index}_#{Time.now}.png"

      plot.data << Gnuplot::DataSet.new( [x,y[0]]) do |ds|
        ds.with = "lines"
        ds.title = "knapsack1"
        ds.linewidth = 2
      end

      plot.data << Gnuplot::DataSet.new( [x,y[1]]) do |ds|
        ds.with = "lines"
        ds.title = "knapsack2"
        ds.linewidth = 2
      end

#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

def plot_dcmoga(index, moga,sga1,sga2, max)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "[No.#{index}]DCMOGA 解の分布 max: #{max[0]}, #{max[1]} 個体数:MOGA-100,SGA-10"

      plot.ylabel 'f_1'
      plot.xlabel 'f_2'
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "glaph/DCMOGA/#{Time.now}.png"
      plot.xrange '[3000:4500]'
      plot.yrange '[3000:4500]'

      ga = [moga,sga1,sga2]
      [moga,sga1,sga2].each do |ga|
        score = [ga.collect {|gene| gene.score[0]},ga.collect {|gene| gene.score[1]}]

        puts "ga size : #{ga.size}"
        puts "score size: #{score[0].size} : #{score[1].size}"
        puts "score"
        p score

        plot.data << Gnuplot::DataSet.new( [score[0],score[1]] ) do |ds|
          ds.with = "points pt 7"
          ds.notitle
#        ds.linewidth = 2
        end
      end

#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

def plot_pareto(index, pareto)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "[No.#{index}]DCMOGA パレート解の分布[個体数:#{pareto.size}]"

      plot.ylabel 'f_1'
      plot.xlabel 'f_2'
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "glaph/pareto/#{Time.now}.png"
      plot.xrange '[3000:4500]'
      plot.yrange '[3000:4500]'

      puts "pareto.size : #{pareto.size}"
      puts "pareto.uniq.size : #{pareto.uniq.size}"
#      puts "pareto"
#      p pareto

      score = [pareto.collect{|gene| gene.score[0]}, pareto.collect{|gene| gene.score[1]}]
        plot.data << Gnuplot::DataSet.new( [score[0],score[1]] ) do |ds|
          ds.with = "points pt 7"
          ds.notitle
#        ds.linewidth = 2
        end

#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

def plot_moga(index, x,y, max)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "[No.#{index}]MOGA パレート解の分布 max: #{max[0]}, #{max[1]} 個体数:MOGA-100,SGA-10"

      plot.ylabel 'f_1'
      plot.xlabel 'f_2'
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "glaph/MOGA/#{Time.now}.png"
      plot.xrange '[0:4500]'
      plot.yrange '[0:4500]'

      plot.data << Gnuplot::DataSet.new( [x,y] ) do |ds|
        ds.with = "points pt 7"
#        ds.notitle
#        ds.linewidth = 2
      end

#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

def plot_migrate(evaluations, moga, sga, index)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "[No.#{index}]評価回数の推移 個体数:MOGA-100,SGA-10"

      plot.ylabel 'Number of Evaluation in each subpopulation'
      plot.xlabel 'Number of Evaluations'
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "glaph/Eval_count/#{Time.now}.png"

      plot.data << Gnuplot::DataSet.new( [evaluations,moga] ) do |ds|
        ds.with = "lines dt (5,5)"
        ds.title = "MOGA"
#        ds.notitle
#        ds.linewidth = 2
      end

      plot.data << Gnuplot::DataSet.new( [evaluations,sga[0]] ) do |ds|
        ds.with = "lines"
        ds.title = "SGA1"
#        ds.notitle
        ds.linewidth = 1
      end

      plot.data << Gnuplot::DataSet.new( [evaluations,sga[1]] ) do |ds|
        ds.with = "lines dt (10,10)"
        ds.title = "SGA2"
#        ds.notitle
        ds.linewidth = 1
      end



#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

def plot_benchmark(i,bench)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "計算時間の推移"

      plot.ylabel "計算時間"
      plot.xlabel "評価回数"
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "glaph/bench/bench_#{i}_#{Time.now}.png"

      max = bench.size

      plot.data << Gnuplot::DataSet.new([[*0..max],bench]) do |ds|
        ds.with = "lines"
        ds.notitle
#        ds.title = "roulette_select"
      end
#      plot.data << Gnuplot::DataSet.new([[*0..max],bench[1]]) do |ds|
#        ds.with = "lines"
#        ds.title = "crossover"
#      end
#      plot.data << Gnuplot::DataSet.new([[*0..max],bench[2]]) do |ds|
#        ds.with = "lines"
#        ds.title = "ranking_method"
#      end
#      plot.data << Gnuplot::DataSet.new([[*0..max],bench[3]]) do |ds|
#        ds.with = "lines"
#        ds.title = "pop"
#      end
#      plot.data << Gnuplot::DataSet.new([[*0..max],bench[4]]) do |ds|
#        ds.with = "lines"
#        ds.title = "check"
#      end

    end
  end
end


if __FILE__ == $0

  total_max = Array.new(2,[])
  $population = 100

  $bags = Array.new

  open('./testdata') do |file| #.read.split("\n")
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

  $item_size = $bags[0].weights.size

  $bench = Array.new(5,[])

#  Parallel.each([*0..10], in_thread: 4) do |t|
#  Parallel.each([*0..4], in_processes: 5) do |t|
  1.times do |t|

    $bench = Array.new(5,[])

    plot_x = []
    plot_y = Array.new(2){[]}

    agent = DCMOGA.new(population: 100, to_migrate: 4000,time:t)
#    agent = DCMOGA.new(population: 500, to_migrate: 100*2000)

    puts "#{t} times..."

    eval_moga = []
    eval_sga = Array.new(2,[])
    evaluations = []

    max = [0,0]
#    agent.start do |index, generation, max_fitness|
    agent.start do |generation, max_fitness, to_migrate_moga, to_migrate_sga|
#      if generation%1000 == 0
#        puts "#gen #{generation} max_fitness : #{max_fitness[0]}, #{max_fitness[1]}"
#      end
#      p index, generation, max_fitness
      max = max_fitness
#      plot_x << generation
#      plot_y[index] << max_fitness
#    break if gets =~ /x/

      eval_moga << to_migrate_moga
      eval_sga[0] << to_migrate_sga[0]
      eval_sga[1] << to_migrate_sga[1]
      evaluations << generation
    end

#    puts "sga1 max_fitness: #{max[0]}"
#    puts "sga2 max_fitness: #{max[1]}"

    total_max[0] << max[0]
    total_max[1] << max[1]


    # プロットの際にMOGA,SGA1,SGA2をすべて合わせる
    moga = agent.moga.genes
    sga1 = agent.sga1.genes
    sga2 = agent.sga2.genes

#    score = [ga.collect {|gene| gene.score[0]},ga.collect {|gene| gene.score[1]}]
#    plot_dcmoga(t, score[0],score[1], max)
    plot_dcmoga(t, moga,sga1,sga2,max)

    puts "plotted to glaph/DCMOGA/#{t}_#{Time.now}.png"

    plot_pareto(t,agent.pareto)
    puts "plotted to glaph/pareto/#{t}_#{Time.now}.png"

#    score = [agent.moga.genes.collect {|gene| gene.score[0]},agent.moga.genes.collect {|gene| gene.score[1]}]
#    plot_moga(t, score[0],score[1], max)

#    puts "plotted to glaph/MOGA/#{t}_#{Time.now}.png"

    plot_migrate(evaluations,eval_moga,eval_sga,t)
    puts "plotted to glaph/Eval_count/#{t}_#{Time.now}.png"

#    5.times do |i|
#      plot_benchmark(i,$bench[i])
#      puts "plotted to glaph/bench/#{t}_#{Time.now}.png"
#    end
  end

#  puts"total_sga1_max_fitness : #{total_max[0].max}"
#  puts"total_sga2_max_fitness : #{total_max[1].max}"


end
