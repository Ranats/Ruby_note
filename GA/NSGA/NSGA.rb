require './Aroma' # DB
require 'matrix'  # vectorを使うためのgem

class NSGA_II

  attr_accessor :population

  def clone(args)
    Marshal.load(Marshal.dump(args))
  end

  def initialize(population,request)

    # Step.1 t=0, 探索母集団P_tを初期化し，アーカイブ母集団Q_tを空にする．
    @population = population
    @generation = 0

    @limit_size = population.size

    @pareto = []

    # 減少率
    @reduction_rate = population.size / 10

    @request = request
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
  def fast_nondominated_sort(population)

    #ruling_population = []
    #ruled_population = []

    #p population.size
    population.each do |pop|
    #  ruling_population = population.reject{|item| item==pop}.select{|other| other.fitness[0]>pop.fitness[0] && other.fitness[1]>pop.fitness[1] && other.fitness[2]>pop.fitness[2]}
    #  ruled_population = population.reject{|item| item==pop}.select{|other| other.fitness[0]<pop.fitness[0] && other.fitness[1]<pop.fitness[1] && other.fitness[2]<pop.fitness[2]}

    #  pop.ruled = ruled_population.size

    #  if pop.ruled == 0
    #    pop.rank = rank
    #  end

      pop.ruled = population.count{ |other| other.fitness.norm < pop.fitness.norm}
      pop.ruling = population.count{ |other|  pop.fitness.norm < other.fitness.norm}
    end

    rank = 0

    ranked_pop = population.select{|pop| pop.ruled==0}

    while ranked_pop.size > 0
      ranked_pop = population.select{|pop| pop.ruled==0}
      ranked_pop.each{|pop| pop.rank = rank; pop.ruled -= 1}

      ranked_pop.each do |pop|
        ruling_population = population.reject{|item| item==pop}.select{|other| pop.fitness.norm < other.fitness.norm}
        ruling_population.each{|rpop| rpop.ruled -= 1}
      end
      rank += 1
    end


#    gets
#    population.each{|pop| pop.ruled -=1}

#    fast_nondominated_sort(population.reject{|item| item.ruled < 0 },rank+1)


    # ruledの配列 をソート したものをuniqした配列でeach
 #   population.sort_by{|p| p.ruled}.collect{|p| p.ruled}.uniq.each_with_index  do |r,current_rank|
 #     population.map{|pop| pop.rank = current_rank if pop.ruled == r}
 #   end

#    puts "fitness.norm : ruled_individual : rank"
#    population.sort_by{|p| p.ruled }.each do |s|
#      puts "#{s.fitness.norm} : #{s.ruled} : #{s.rank}"
#    end
  end

  def calc_crowding_distance(population)
    ret = []
    (population.min_by{|pop| pop.rank}.rank..population.max_by{|pop| pop.rank}.rank).each do |i|
      front = population.select{|pop| pop.rank == i}

#      front.each do |fr|
#        puts %(#{fr.fitness})
#      end
      3.times do |f|
        front.sort_by!{|pop| pop.fitness[f]}
        f_max = front.max_by{|pop| pop.fitness[f]}.fitness[f]
        f_min = front.min_by{|pop| pop.fitness[f]}.fitness[f]
        front.first.distance = Float::INFINITY
        front.last.distance = Float::INFINITY
        if f_max == f_min
          next
        else
          (1..front.size-2).each do |idx|
#            puts %(idx:#{idx})
#            puts %(f_max:#{f_max}, f_min:#{f_min})
            front[idx].distance += (front[idx+1].fitness[f] - front[idx-1].fitness[f]) / (f_max - f_min)
#            puts %(dist:#{(front[idx+1].fitness[f] - front[idx-1].fitness[f]) / (f_max - f_min)})

#            puts "distance"
#            puts %(+1: #{front[idx+1].fitness[f]} -1: #{front[idx-1].fitness[f]})
#            puts %(front[idx].distance: #{front[idx].distance})
#            gets
          end
        end
      end

      ret += front

#      puts "ret"
#      front.each do |r|
#        puts %(#{r.distance})
#      end
#      gets
    end
    return ret
  end

  def crowding_sort(population)
    # ソートされたものを返す
    population.sort_by{|pop| pop.distance}
  end

  def crowding_tournament_select(population)
    # トーナメントサイズ2: 2個体をランダムに選び，以下の2点の選択基準により選択．
    #   母集団における非優越ランク : 個体iのランクの方が個体jのランクよりも優れている
    #   母集団内の局所的混雑距離  : 個体iと個体jはともに同じランクであり，iの混雑距離がjよりも優れている．
    pop = [clone(population[rand(population.length)]),clone(population[rand(population.length)])]
    pop[0].rank == pop[1].rank ? (pop[0].distance > pop[1].distance ? pop[0] : pop[1]) : pop[0].rank > pop[1].rank ? pop[1] : pop[0]
  end

  def crossover(pair, position)
    child = clone(pair)
    child[0].chromosome = pair[0].chromosome.take(position) + pair[1].chromosome.drop(position)
    child[1].chromosome = pair[1].chromosome.take(position) + pair[0].chromosome.drop(position)

    # 交叉後の交叉位置以降の1の数　- 交叉前の交叉位置以降の1の数\
    #   調整する対象のビットを指定 1/0
    #   調整するビットのインデックス配列を生成
    #   その中からランダムに選び，そのインデックスのビットを反転する．
    2.times do |id|
      gap = child[id].chromosome.drop(position).inject(:+) - pair[id].chromosome.drop(position).inject(:+)
      target_bit = (gap > 0) ? 1 : 0
      (gap.abs).times do |i|
        idxs = child[id].chromosome.map.with_index{|e,i| e == target_bit ? i : nil}.compact
        child[id].chromosome[idxs[rand(idxs.length)]] = 1^target_bit
      end
    end

    child
  end

  def next_generation
    # N=P_tの大きさ
    # 1.P_t+1...非優越ソートを行い，ランク付けを行った個体，の上位N個体
    # 2.P_t+1の大きさ = N ?
    # 3.P_t+1から混雑度トーナメント選択により 大きさN のQ_t+1を生成
    #   Q_t+1に対して遺伝的操作を行う?
    # 4.R_t = P_t+1 + Q_t+1
    # 評価し，1に戻る

    # http://www.anlp.jp/proceedings/annual_meeting/2014/pdf_dir/P6-10.pdf
    # 交叉
    #   一点交叉を用い，交叉前と交叉後で"1"の数が異なる場合，調整を行う
    # 突然変異
    #   0と1が隣り合う箇所を探し，それらの場所を入れ替える．


    # Step.2 R_tの評価を行う
    @population.each {|pop| pop.calc_fitness}

    # 評価値の正規化
    # 取りうる値の最大値と最小値を用いて

    # Step.3 アーカイブ集団(=パレート集合?)と探索母集団を組み合わせて R_t = P_t U Q_t を生成する。
    #@population = @pareto.clone + @population.clone

    # R_t に対して非優越ソートを行い、全体をフロント毎(ランク毎)に分類する：F_i, i=1, 2, ...
    fast_nondominated_sort(@population)

    @population.sort_by!{|pop| pop.rank}


    # 混雑距離を計算
    @population = calc_crowding_distance(@population)



    # 上位N個体をP_t+1とする．
    # Step 4 新たなアーカイブ母集団 Pt+1 = φ を生成．変数 i = 1 とする．
    # |Pt+1| + |Fi| > N を満たすまで，Pt+1 = Pt+1 ∪ Fi と i = i + 1 を実行．

    i = 0
    population_p = []
    ranked_population = @population.select{|pop| pop.rank == i}
    while population_p.size + ranked_population.size < @limit_size
      population_p += ranked_population
      i += 1
      ranked_population = @population.select{|pop| pop.rank == i}
    end

    # Step 5 混雑度ソート (Crowding-sort) を実行し，Fi の中で最も多様性に優れた（混雑距離の大きい）
    # 個体 N − |Pt+1| 個を Pt+1 に加える．
      # Step.4であふれたF_i...同一ランク(同一フロント)の個体群に対して用いる．
    population_p += crowding_sort(ranked_population).take(@population.size - population_p.size)


    # Step 6 終了条件を満たしていれば，終了する．

    # Step 7 Pt+1 を基に，混雑度トーナメント選択により新たな探索母集団 Qt+1 を生成する．
    population_q = []

    @limit_size.times do
      population_q << crowding_tournament_select(population_p)
    end

    # Step 8 Qt+1 に対して遺伝的操作（交叉，突然変異）を行う．
      # 交叉
    (population_q.size/2).times do
      crossover([population_q[rand(population_q.length-1)],population_q[rand(population_q.length-1)]],rand(@population[0].chromosome.length-1)).map do |c|
        population_q << c
      end
    end

      # 突然変異
    population_q.each do |c|
      c.chromosome.map.with_index {|p,idx| rand(0.0..1.0) < 0.05 ? c.mutate(idx) : p}
    end

      # 致死遺伝子の処理
    population_q.each do |c|
      while c.chromosome.inject(&:+) > c.limit
        c.chromosome[rand(0..c.chromosome.length)] = 0
      end
      req = clone(@request)
      c.chromosome.each_with_index do |bit,idx|
        if bit == 1
          req -= Aroma.get[idx][:effect]
        end
      end
      unless req.empty?
        c.fitness = nil
      end
    end

    population_q.reject!{|pop| pop.fitness.nil?}

    # t = t + 1 をとし，Step 2 に戻る．

    # 4.R_t = P_t+1 + Q_t+1
    @population = population_p.clone + population_q.clone

    @population
  end
end
