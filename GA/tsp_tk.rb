require 'tk'

#セールスマンの人数
SALESMEN = 300
#ポイントの数
POINTS = 30
#世代数
LASTG = 1000
#キャンバスの横幅
WIDTH = 300
#キャンバスの縦幅
HEIGHT = 300

class Salesman

  attr_accessor :gene

  def initialize(points)
    #遺伝子は座標の配列を、巡回する順にならべたもの
    #[[x1,y1],[x2,y2],[x3,y3],……[xmax],[ymax]]
    @gene = points.shuffle
  end

  #任意の２点を入れ替える
  def mutate_1
    i, j = rand(POINTS), rand(POINTS)
    @gene[i],@gene[j] = @gene[i],@gene[j]
  end

  #隣の２点を入れ替える
  def mutate_2
    i = rand(POINTS-1) # i は0〜48。49はNG注意
    @gene[i],@gene[i+1] = @gene[i+1],@gene[i]
  end

  #１点だけ他の場所へ
  def mutate_3
    i, j = rand(POINTS), rand(POINTS)
    temp = @gene.slice!(i)
    @gene.insert(j, temp)
  end

  #一部分を逆回転する
  def mutate_4
    i = (Array.new(2){rand(POINTS)}).sort
    @gene[i[0]..i[1]] = @gene[i[0]..i[1]].reverse
  end

  #距離の合計を求める
  def score
    @gene.each_cons(2).inject(0) do |sum, (p1,p2)|
      x1, y1 = *p1; x2, y2 = *p2
      sum + Math::sqrt(((x1-x2)**2) + ((y1-y2)**2))
    end
  end

  #オブジェクトのコピー用
  #Salesmanをcloneした時に、@geneの内容もコピーして生成する。
  #これ書かないと、単にコピー元の@geneの参照が渡されてしまうみたい。
  def initialize_copy(obj)
    @gene = obj.gene.dup
  end

end

class Company

  def initialize
    #巡回ポイントの座標
    @points = Array.new(POINTS){[rand(WIDTH),rand(HEIGHT)]}
    #セールスマン詰め合わせ
    @pool = Array.new(SALESMEN){Salesman.new(@points)}
    #世代数
    @generation = 1
    #その時点での最高の遺伝子を保存用
    @record = []
  end

  attr_reader :generation, :record

  def checkResult
    #成績順に並べ替え
    @pool.sort_by!{|salesman| salesman.score}
    #最優秀遺伝子を記録
    @record << @pool[0].gene.clone
    #下位1/20はトップと入れ替え
    @pool[-(@pool.size/20)..-1] = Array.new(@pool.size/20){@pool[0].clone}
  end

  def mutate
    #突然変異を行う
    @pool.each do |salesman|
      case rand(100)/100.0
        when 0..0.05
          salesman.mutate_1
        when 0.05..0.25
          salesman.mutate_2
        when 0.25..0.30
          salesman.mutate_3
        when 0.30..0.35
          salesman.mutate_4
      end
    end
  end

  #最短記録が更新されたかチェック
  def new_champion?
    @record.last != @record[-2]
  end

  def best_gene
    @record.last
  end

  def tick
    @generation += 1
  end

  def best_score
    @pool[0].score
  end

end

class ViewController

  def initialize
    @root = TkRoot.new(title:"Ruby/Tk 巡回セールスマン")
    @generation_label = TkLabel.new(@root).pack
    @canvas = TkCanvas.new(@root, width:WIDTH, height:HEIGHT).pack
    @button = TkButton.new(text:"スタート").pack
    @button.command proc{start}
    @company = Company.new
  end

  def start
    LASTG.times{round}
    puts "end"
  end

  def round
    @company.checkResult
    if @company.new_champion?
      @generation_label.text = "#{@company.generation}：#{@company.best_score.round}"
      show(@company.best_gene)
    end
    @company.mutate
    @company.tick
  end

  def show(gene)
    @canvas.delete :all
    #線を引く
#    p gene
#    gene.size.step(2) do |i|
#      TkcLine.new(@canvas, gene[i][0],gene[i][1],gene[i+1][0],gene[i+1][1], width: 10 ,fill: :red)
#    end

p    TkcLine.new(@canvas, 0,0, 10,10, 'fill'=>'red')
    #ポイントを□で描出
    gene.each { |x,y|
#      TkcLine.new(@canvas,x,y, fill: :red)
      TkcOval.new(@canvas, x-3,y-3,x+3,y+3,)
    }

#    10.times do |x|
#      TkcOval.new(@canvas,@company.generation,x*10,@company.generation+10,x*10)
#    end
    #↓これ入れておかないと表示されない
    Tk.update
  end

end

ViewController.new

Tk.mainloop
