module Scanner
  Encoding.default_external = 'UTF-8'
  module_function
  def get_aroma(request)
    aromas = []
    File.foreach('../db/raw_data') do |line|
      hash = {}
      line.chomp.split(',').each do |item|  #=> ["name:アンジェリカルート", "effect:0:2:3:9", ...]
        set = item.split(':')               #=> ["name", "アンジェリカルート"]
        hash[set[0].to_sym] =
            set[0] == "effect" ? set.drop(1).map(&:to_i) : set[0]!="name" ? set[1].to_i : set[1]
      end

      # 効能のリクエストを含むものなら配列に追加
        # request       :[1,2,3]
        # hash[:effect] :[0,2,5,9]
        # request - hash[:effect] => [1,3] # 2が減算される
      aromas << hash if (request - hash[:effect]).size != request.size
    end
    aromas
  end
end
