require './gen_testdata'
require 'test/unit'

class TestBag < Test::Unit::TestCase

  def test_bag1
    bag = Generator.new
    bag.bag1
    assert_equal 100 , bag.weights.size
    assert_equal 100 , bag.values.size

    assert_true bag.weights.all?{|item| item.kind_of?(Fixnum)}
    assert_true bag.values.all?{|item| item.kind_of?(Fixnum)}

  end

end
