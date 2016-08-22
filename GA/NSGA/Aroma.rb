module Aroma

  # 精油群の生成の部分で、目的の効能リクエストを受け取ってそれらを満たす精油のみで構成された精油群を生成するように?
  # get_aroma(request)
  #  @@item = Scanner.get_aroma

  def create(request)
    @@item = Scanner.get_aroma(request)
  end

  def get
    @@item
  end

  module_function :get
  module_function :create
end
