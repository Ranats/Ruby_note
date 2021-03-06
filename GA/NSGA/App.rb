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
      plot.output "#{Time.now}.png"
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
    sleep 1
  end

  Aroma.create(request)

  # 精油の数を遺伝子長として初期化 => [0,0,1,1,0,0,...]
  population = Array.new(Settings.individual_size) { Gene_b.new(Aroma.get.size) }

  # B
  # requestサイズで遺伝子を初期化　=> [0, 15, 3] , [1, 9, 3] , ...
  # と同時に初期集団を評価
#  population = Array.new(Settings.individual_size) { Gene_a.new(request.size) }


#  population.map{|pop| p pop.fitness; }#pop.chromosome.each_with_index do |bit,i| p Aroma.get[i][:name] end}

  # Step.1 t=0, 探索母集団Qtを初期化し、アーカイブ母集団Ptを空にする
  agent = NSGA_II.new(population)

  agent.next_generation

  plot_pareto(agent.population)

end
