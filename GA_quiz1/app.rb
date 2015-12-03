# 写経

class Genes
  def initialize(gene_count = 10, quiz_count = 10)
    @generation = 1
    @quiz = Quiz.new(quiz_count) # 正解用の長さ10(quiz_count)geneを1つ生成
    p @quiz
    while max == quiz_count # 初期状態で最も適応度が高いものがすべて正解だった場合作り直し？
      @genes = []
      gene_count.times do
        @genes << Gene.new(quiz_count) # 長さ10(quiz_count)の個体を10個生成して@genes配列に格納
      end
      mark # 正誤を判定して適応度(score)を計算。
      sort # 適応度が高い順にソート
    end
  end

  def start
    while max < @quiz.count # 適応度が最大になるまでループ
      yield(@generation, @genes, max, min, average) # 引数として渡されたブロックに指定する引数を設定。ブロックを実行
      next_generation # つぎの世代へ
      mark # 正誤を判定して適応度(score)を計算。
      sort # 適応度が高い順にソート
    end
    yield(@generation, @genes, max, min, average)
  end

  # 各個体(遺伝子)の評価
  def mark
    @genes.length.times do |i|
      @genes[i].score = @quiz.mark(@genes[i].ans)
    end
  end

  # 各個体(遺伝子)を評価の高い順にソート
  def sort
    @genes.sort! { |a, b| a.score <=> b.score }.reverse!
  end

  # 世代を進める
  # 上位2つの個体を親として交叉を行う。
  # すでに各個体はソートされているので、適応度の低い2つが置き換わる。他は据え置き（エリート選択？）
  def next_generation
    @generation += 1
    pair = []
    pair << @genes[0]
    pair << @genes[1]
    pair = breed(pair) # 交叉
    @genes[@genes.length-2] = pair[0]
    @genes[@genes.length-1] = pair[1]
  end

  # 一点交叉?
  def breed(parents)
    c = parents[0].count
    children = [Gene.new(c), Gene.new(c)]
    cross = rand(c-1)
    c.times do |i|
      n = (i < cross) ? 0 : 1
      children[0].ans[i] = parents[(0+n)%2].ans[i]
      children[1].ans[i] = parents[(1+n)%2].ans[i]
    end

    # 突然変異
    mutation = rand(c)
    children[0].ans[mutation] = rand(3) if mutation < c
    mutation = rand(c)
    children[1].ans[mutation]=rand(3) if mutation < c
    children
  end

  def max
    @genes ? @genes[0].score : @quiz.count
  end

  def min
    @genes ? @genes[(@genes.length - 1)].score : 0
  end

  def average
    sum = 0
    @genes.each do |x|
      sum += x.score
    end
    sum / @genes.length
  end
end

class Gene
  def initialize(count)
    @count = count
    @ans = []
    @count.times do
      @ans << rand(3)
    end
  end

  attr_accessor :score
  attr_accessor :ans
  attr_accessor :count
end

class Quiz < Gene
  def mark(ans)
    score = 0
    @count.times do |i|
      score += 1 if @ans[i] == ans[i]
    end
    score
  end
end

# ui
g = Genes.new
g.start do |generation, genes, max, min, average| #yield文によって実行されるブロック内で使われる変数
  puts 'generation  : ' + generation.to_s
  puts 'max fitness : ' + max.to_s
#  p min
#  p average
  10.times do |i|
    print genes[i].ans, genes[i].score, "\n"
  end
  break if gets =~ /x/
end