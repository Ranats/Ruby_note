require './Get_aroma'
#include Scanner
require './Aroma'
#require './NSGA-III'
#require './NSGA-IIIb'

module Settings
  module_function
  def individual_size; 100 end
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

  population = Array.new(Settings.individual_size) { Gene.new(Aroma.get.size) }

  population.map{|pop| p pop.fitness; }#pop.chromosome.each_with_index do |bit,i| p Aroma.get[i][:name] end}

  agent = NSGA_III.new(population)

end
