=begin
参考
遺伝的アルゴリズム - wikipedia
https://ja.wikipedia.org/wiki/%E9%81%BA%E4%BC%9D%E7%9A%84%E3%82%A2%E3%83%AB%E3%82%B4%E3%83%AA%E3%82%BA%E3%83%A0#.E4.B8.80.E7.82.B9.E4.BA.A4.E5.8F.89
遺伝的アルゴリズム GA 入門
～遺伝的アルゴリズムを用いたテストケースの生成～
http://www.zipc.com/cesl/info/04.pdf
遺伝的アルゴリズムの用語集
http://mikilab.doshisha.ac.jp/dia/research/pdga/words.html
組み合わせ最適化 - wikipedia
https://ja.wikipedia.org/wiki/%E7%B5%84%E5%90%88%E3%81%9B%E6%9C%80%E9%81%A9%E5%8C%96#.E5.95.8F.E9.A1.8C.E4.BE.8B

GA/DGAのパラメータ(3) -- 選択（エリート保存戦略について）
http://mikilab.doshisha.ac.jp/dia/research/person/jiro/reports/GAparams/GAparams03.html
GA/DGAのパラメータ(2) -- 選択（スケーリング手法，選択手法）
http://mikilab.doshisha.ac.jp/dia/research/person/jiro/reports/GAparams/GAparams02.html

ＧＡによるナーススケジューリング問題の解法
http://www.kushiro-ct.ac.jp/library/kiyo/kiyo36/kosimizu.pdf

分散遺伝的アルゴリズムにおける
パラメータの検討
http://mikilab.doshisha.ac.jp/dia/research/person/jiro/thesis/graduate.pdf

スライド
https://t.co/vSYMg58sA2

Ruby関数の引数を配列でまとめて渡す。
http://takuya-1st.hatenablog.jp/entry/2014/02/24/174150

遺伝アルゴリズムによる NQueen 解法
http://www.info.kindai.ac.jp/~takasi-i/thesis/2011_07-1-037-0276_M_Imamura_thesis.pdf
エイト・クイーン - wikipedia
https://ja.wikipedia.org/wiki/%E3%82%A8%E3%82%A4%E3%83%88%E3%83%BB%E3%82%AF%E3%82%A4%E3%83%BC%E3%83%B3
=end

@data = '80
50
2,21
10,22
7,28
2,21
4,12
9,24
10,15
7,2
8,25
5,28
3,4
10,22
9,36
8,2
8,7
5,40
7,14
3,40
9,33
7,21
2,28
10,22
7,14
9,36
7,14
2,21
10,18
4,12
9,24
10,15
4,21
7,2
8,25
5,28
2,28
3,4
10,22
9,36
7,31
8,2
8,7
5,40
7,14
5,4
7,28
3,40
9,33
7,35
7,21
9,20
0'.split("\n")

# @data = readlines

P_CROSS = 0.6
P_MUTATION = 0.01

#Item = Struct.new(:value, :weight)
Item = Struct.new(:weight, :value)

Problem = []

def init(count = 0)
#  if @data[0] != '0'
    Problem << {Max_weight: @data[0].to_i, N: @data[1].to_i, Items: Array.new(@data[1].to_i)}
    @data[1].to_i.times do |i|
      Problem[count][:Items][i] = Item.new(*@data[i+2].split(',').map(&:to_i))
    end
#    p Problem[count]
    @data = @data[(@data[1].to_i+2)...@data.length]
#    init(count+1)
#  end
end

def aoj
  n, w = gets().chomp.split(' ').map(&:to_i)
  @data = []
  @data << w
  @data << n
  n.times do |i|
    @data << gets().chomp.split(' ').join(',')
  end

  Problem << {Max_weight: @data[0], N: @data[1], Items: Array.new(@data[1])}
  @data[1].times do |i|
    Problem[0][:Items][i] = Item.new(*@data[i+2].split(',').map(&:to_i))
  end
end

class GA

  # 0: 入れない。 1: 入れる。
  GENE = Struct.new(:score, :chromosome)

  def initialize(population, items, max)
    @generation = 1
    @population = population # 個体数
    @items = items
    @max = max # ナップサックの最大容量
    @size = items.length # 遺伝子長
    @genes = Array.new(@population) { GENE.new(0, Array.new(@items.length)) }
    start_time = Time.now
#    p @items

#    srand(start_time.sec)

    @genes.each do |gene|
      gene.chromosome.map! { |locas| locas = rand(2) }
#      puts gene
    end

    evaluate(@genes)

    sort_genes
#   puts @genes

  end

  def evaluate(genes)
    genes.each do |gene|
      value_sum = 0
      weight_sum = 0
      gene.chromosome.each_with_index do |locas, index|
        if locas == 1
          value_sum += @items[index].value
          weight_sum += @items[index].weight
        end
      end
      if weight_sum <= @max && weight_sum != 1
        gene.score = value_sum
      else
        gene.score = 1
      end
    end
#   puts genes
  end

  def sort_genes
    @genes.sort_by! { |gene| -gene.score }
  end


  def start
    prev = 0
    end_count = 0
    loop do
      yield(@generation, @genes[0, @population], @genes[0], avg)
      selection
      mutation

      evaluate(@genes)
      sort_genes
#      puts @genes

      if prev == @genes[0].score && prev != 1
        break if end_count > 100
        end_count += 1
      else
        end_count = 0
      end
      prev = @genes[0].score
      @generation += 1
    end

    value_sum = 0
    weight_sum = 0
    @genes[0].chromosome.each_with_index do |locas, index|
      if locas == 1
        value_sum += @items[index].value
        weight_sum += @items[index].weight
      end
    end
    puts "value_sum : " + value_sum.to_s
#    puts value_sum.to_s
    puts "weight_sum : " + weight_sum.to_s


    yield(@generation, @genes[0, @population], @genes[0], avg)
  end


  def selection
    # エリート保存
    # エリート個体は交叉に参加する？
    # http://mikilab.doshisha.ac.jp/dia/research/person/jiro/reports/GAparams/GAparams03.html
    # 保存しておいて、交叉、突然変異の後に"追加”する。
    # 次の世代で選択を行う時に個体数を揃える？

    # エリート個体を優先して選択する？ ←
    #    @genes.first.chromosome = @parents.first.chromosome

    #    @parents = Marshal.load(Marshal.dump(@genes))
    @parents = Array.new(@population)
    @elite = Marshal.load(Marshal.dump(@genes[0]))
    @parents[0] = @elite

#    p @genes

    linear_scaling

# ルーレット選択
#    1.upto((@size)/2) do |i|
# すべての個体に対してルーレット選択を行う
#    p sum
#    p @genes
    1.upto(@population-1) do |i|
      @parents[i] = Marshal.load(Marshal.dump(@genes[roulette(rand(sum))]))
#      crossover(roulette,roulette,@size-(i*2-1),@size-(i*2))
    end

    @genes = []

# 適合度の高い個体から交叉,次の世代へ追加していく ? 交叉する個体をランダムで選ぶ => N ~ 2N 個体?
#    count = 0
    @population.times do |i|
      @population.times do |j|
        if rand <= P_CROSS
          crossover(i, j) #, count, count+1)
#          count += 2
#          break if count > @population
          break
        else
          @genes << @parents[i]
          break
        end
      end
    end

  end


  # 線形スケーリング
  # 適合度 fi を f'i に変換する。
  # a = 1 , b = (fN - f1*N) / N -1  =>  f'i = a * fi + b
  def linear_scaling
    f_avg = avg
    f_max = @genes[0].score
    f_min = @genes[-1].score
#    p f_avg, f_min

    return if f_avg == f_min

    a = 0
    b = 0
    c = 2.0
    n = @parents.length

#    p f_min >= (c * f_avg - f_max)/(c - 1.0)

    if f_min >= (c * f_avg - f_max)/(c - 1.0)
      a = (c - 1.0) * f_avg / (f_max - f_avg)
      b = f_avg * (f_max - c*f_avg)/(f_max - f_avg)
    else
      a = f_avg / (f_avg - f_min)
      b = -f_min * f_avg / (f_avg - f_min)
    end
    @genes.each { |gene| gene.score = a * gene.score + b }
  end

  def roulette(prob)
#    puts "sum : %d" % sum
    @genes.each_with_index do |gene, index|
      prob -= gene.score
      return index if prob < 0
    end
  end

  # 2点交叉
  def crossover(p1, p2) #, c1, c2)
#    p p1, p2
    parent1 = Marshal.load(Marshal.dump(@parents[p1]))
    parent2 = Marshal.load(Marshal.dump(@parents[p2]))

    start_id = rand(@size)
    cross_length = rand(@size - start_id)

    parent1.chromosome[start_id, cross_length], parent2.chromosome[start_id, cross_length] = parent2.chromosome[start_id, cross_length], parent1.chromosome[start_id, cross_length]
    @genes << parent1
    @genes << parent2
#@genes[c1].chromosome = parent1
#@genes[c2].chromosome = parent2
#    evaluate(@genes[-1])
#    evaluate(@genes[-2])
  end

  def mutation
    @genes.each_with_index do |gene, index|
      if rand <= P_MUTATION
        i = rand(@size)
        gene.chromosome[i] = (gene.chromosome[i] - 1).abs
      end
    end
  end

  def sum
#    p @genes
#    p @genes.map{|item| item[:score]}
    @genes.map { |item| item[:score] }.inject(:+)
  end

  def avg
    sum / @genes.length
    #sum = @genes.select{|item| item[:score]>1}
    #sum.map{|item| item[:score]}.inject(:+)/sum.length
    #    p sum.inject{|arr,item| arr + item[:score]}#/sum.length
  end

end


if __FILE__ == $0
#  aoj
  init
  p Problem
#  p Problem[0][:Items][0].weight

  population = 32

  Problem.each do |problem|
    ga = GA.new(population, problem[:Items], problem[:Max_weight])
    ga.start do |generation, genes, max_score, average|
#      puts 'generation : ' + generation.to_s
#      puts 'elite : ' + genes[0].to_s
#      genes.each do |item|
#        p item
#      end
#      break if gets =~ /x/
    end

  end


end