require './Get_aroma'
#include Scanner
require './Aroma'
require './NSGA'
require './Gene'
require 'gnuplot'

module Settings
  module_function
  def individual_size; 100 end
end


def plot_pareto(pareto)
  Gnuplot.open do |gp|
    Gnuplot::SPlot.new(gp) do |plot|
      plot.title ""

      plot.ylabel 'f_1'
      plot.xlabel 'f_2'
      plot.zlabel 'f_3'
      plot.terminal 'pngcairo size 1280,1280'
      plot.output "~/graph/#{Time.now}.png"
      plot.xrange '[0:1]'
      plot.yrange '[0:1]'

      score = [pareto.collect{|gene| gene.fitness[0]}, pareto.collect{|gene| gene.fitness[1]}, pareto.collect{|gene| gene.fitness[2]}]
      plot.data << Gnuplot::DataSet.new( [score[0],score[1],score[2]] ) do |ds|
        ds.with = "points pt 7"
        ds.notitle
#        ds.linewidth = 2
      end

#      plot.set "linesyle 1 linecolor rgbcolor 'orange' linetype 1"
    end
  end
end

$score = []
$gen = []
$elite = []

def plot_transitive
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "上位10個体の評価値の推移"
      plot.ylabel "f_norm"
      plot.xlabel "generation"
      plot.terminal "pngcairo size 1280,1280"
      plot.output "~/graph/#{Time.now}.png"
      plot.yrange '[0:0.5]'
      plot.xrange '[0:'+$gen.length.to_s+']'

      plot.data << Gnuplot::DataSet.new([$gen,$score]) do |ds|
        ds.with = "lines"
        ds.linewidth = 2
        ds.title = 'top 10 avg'
      end

      plot.data << Gnuplot::DataSet.new([$gen,$elite]) do |ds|
        ds.with = "lines"
        ds.linewidth = 2
        ds.title = 'elite'
      end



    end
  end
end

if __FILE__ == $0
  include Settings

  request = []

  # とりあえずのUI
  loop do
    puts "効能を選ぶ(3つまで。空白区切りで)"
    effect = "安眠 集中力アップ ストレス 不安/心配 月経痛 食欲不振 鼻水/花粉症 頭痛 のどの痛み 冷え性 肥満予防 二日酔い 便秘 膀胱炎 乾燥肌 シミ/クスミ シワ/タルミ ニキビ 日焼け むくみ".split(' ')
    effect.each_with_index do |e,i|
      puts "#{i}: #{e}"
    end

    break if (request = gets.chomp.split(' ').map(&:to_i)).size.between?(1,3)
    puts "1つ以上3つまで！！！！！\n\n"
    sleep 0.5
  end

  Aroma.create(request)

  # 精油の数を遺伝子長として初期化 => [0,0,1,1,0,0,...]
  population = Array.new(Settings.individual_size) { Gene_b.new(Aroma.get.size,request) }

  # B
  # requestサイズで遺伝子を初期化　=> [0, 15, 3] , [1, 9, 3] , ...
  # と同時に初期集団を評価
#  population = Array.new(Settings.individual_size) { Gene_a.new(request.size) }


#  population.map{|pop| p pop.fitness; }#pop.chromosome.each_with_index do |bit,i| p Aroma.get[i][:name] end}

  # Step.1 t=0, 探索母集団Qtを初期化し、アーカイブ母集団Ptを空にする
  agent = NSGA_II.new(population,request)

  n = 10

  10000.times do |i|
    agent.next_generation

    vec = 0
    agent.population.take(n).each do |pop|
      vec += pop.fitness.norm
    end

    vec /= n

    $gen << agent.generation

    $score << 1 / vec / 10

    $elite << 1 / agent.population.first.fitness.norm / 10

    if i % 100
#      plot_pareto(agent.population)

      plot_transitive
    end
  end

end
