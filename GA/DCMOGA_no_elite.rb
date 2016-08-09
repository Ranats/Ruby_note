require 'gnuplot'

class Bags
  attr_accessor :capacity, :weights, :values

  def initialize
    @capacity = 0
    @weights = Array.new # 重さ
    @values = Array.new # 価値
  end
end

class Gene
  attr_accessor :score, :chromosome

  def initialize(length)
    @chromosome = []
    length.times do
      @chromosome << rand(2)
    end
    @score = Array.new(2, 0)
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
  attr_accessor :genes, :generation


  def initialize(population: 4, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @population = population
    @crossover_rate = crossover_rate
    @mutation_rate = mutation_rate
    @generation = 0

    @genes = create_genes

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

  def next_generation


  end


  # 一点交叉
  def crossover(parents)
    count = parents[0].chromosome.size - 1
    child = Marshal.load(Marshal.dump(parents))

    start_id = rand(count)

    child[0].chromosome[start_id..count] = parents[1].chromosome[start_id..count]
    child[1].chromosome[start_id..count] = parents[0].chromosome[start_id..count]

    return child

  end

  def mutation(gene, rate)
    if rand < rate
      p = rand($item_size)
      gene.chromosome[p] = (gene.chromosome[p] == 1) ? 0 : 1
    end
    gene
  end

end

class MOGA < GA

end

class SGA < GA


  def sort(i)
    @genes.sort! { |a, b| a.score[i] <=> b.score[i] }.reverse!
  end

  # ルーレット選択
  def roulette_select(i)
    pair = []
    total = @genes.inject(0) { |total, score| total + score.score[i] }


    # ペア2つを作る
    2.times do
      rulet_cf = rand(10000) / 10000.0 * total
#      p rulet_cf
      rulet_num = 0
      rulet_value = 0
      @population.times do |j|
        rulet_value += @genes[j].score[i]
#        p rulet_value
        if rulet_value > rulet_cf
          rulet_num = j
#          p rulet_num
          break
        end
      end
      pair << @genes[rulet_num]
    end

    return pair

  end

  def start(num)
    @generation += 1

    parents = []
    children = []

    # elite
#    children << @genes[0] << @genes[1]

    # 交叉
    while children.size < @population
      parents = roulette_select(num)
      children += crossover(parents)

      children.map(&:evaluate)

      children.each do |child|
        while child.score.min == 0
          child.chromosome[rand($item_size)] = 0
          child.evaluate
        end
      end

    end

    # 突然変異
    children.map do |child|
      mutation(child, 1.0 / $item_size)
    end

    #    p @children.size
    #    p @genes
    #    p @parents
    #    p @children.size

    @genes = children

    @genes.each do |gene|
      gene.evaluate
    end


#    yield(@generation, @genes, )
#    max = @genes.max {|a, b| a.score[num] <=> b.score[num]}

#    p max
#    p @genes
#    n = gets

  end

end

# 遺伝子長 = 荷物(item)数

class DCMOGA

  def initialize(end_of_eval: 20000000, to_migrate: 4000, population: 100, problems: Array.new)
    @generation = 1
    @to_migrate = to_migrate
    @end_of_eval = population * 20000
    @evaluated = 0
    @to_migrate_moga = to_migrate / population
    @to_migrate_sga = Array.new(2, to_migrate / 4)

    @change_rate = 10


    @moga = MOGA.new(population: population, crossover_rate: 1.0, mutation_rate: 0.01)

    # 1世代目のMOGAの個体群
    #    p moga.genes
    #    @moga.genes.each do |gene|
    #      p gene
    #    end

    @sga1 = SGA.new(population: 10, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @sga1.sort(0)
    @sga2 = SGA.new(population: 10, crossover_rate: 1.0, mutation_rate: 1.0 / $item_size)
    @sga2.sort(1)


#    [@sga1,@sga2].each do |sga|
#      sga.genes.each do |gene|
#        p gene
#      end
#    end

  end

  def start
    while @evaluated < @end_of_eval

      # MOGA loop
      while @moga.generation < @to_migrate_moga
        break
      end

      # SGAs loop
      [@sga1, @sga2].each_with_index do |sga, index|
        while sga.generation < @to_migrate_sga[index]
#          puts 'generation  : ' + @sga.generation.to_s
          sga.start(index)
          sga.sort(index)

#          puts 'sga' + index.to_s
#          puts 'max fitness : ' + sga.genes[0].score[index].to_s
#          sga.genes.each do |gene|
#            print gene.chromosome, gene.score[index], "\n"
#          end

#          break if gets =~ /x/

          yield(index, sga.generation, sga.genes[0].score[index])
        end
      end

      self.migration

      # if @moga.genes[0].score[0] > @sga1.genes[0].score
      #   @to_migrate_moga -= @change_rate
      #   @to_migrate_sga[0] += @change_rate
      # else
      #   @to_migrate_moga += @change_rate
      #   @to_migrate_sga[0] -= @change_rate
      # end

      @evaluated = [@moga.generation, @sga1.generation, @sga2.generation].inject(:+)
      break
    end

  end


  def migration

  end

end


def plot(index, x, y)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "SGA_#{index} " + Time.now.to_s

      plot.ylabel 'value'
      plot.xlabel 'generation'
      plot.terminal 'pngcairo'# size 600,1200'
      plot.output "glaph/no_Elite/SGA_#{index}_#{Time.now}.png"

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


if __FILE__ == $0

  20.times do |t|


    plot_x = []
    plot_y = Array.new(2){[]}

    $population = 100

    $bags = Array.new

    open('testdata') do |file| #.read.split("\n")
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

    p $bags

    $item_size = $bags[0].weights.size

#    agent = DCMOGA.new(population: 100, to_migrate: 4000)
    agent = DCMOGA.new(population: 100, to_migrate: 100*20000)

    max = [0,0]
    agent.start do |index, generation, max_fitness|
#      p index, generation, max_fitness
      max[index] = max_fitness
      plot_x << generation
      plot_y[index] << max_fitness
#    break if gets =~ /x/
    end

    puts "#{t} times"
    puts "sga1 max_fitness: #{max[0]}"
    puts "sga2 max_fitness: #{max[1]}"

    plot(t, plot_x, plot_y)

    puts "plotted to glaph/no_Elite/SGA_#{t}_#{Time.now}.png"
  end

end
