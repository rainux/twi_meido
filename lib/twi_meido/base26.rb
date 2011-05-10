class Integer
   Base26Digits = ('A'..'Z').to_a.freeze

   def to_base26
     number = self
     base26 = []
     until number == 0
       mod = number % 26
       base26 << Base26Digits[mod]
       number = (number - mod) / 26
     end
     base26.empty? ? Base26Digits[0] : base26.reverse!.join
   end

   alias_method :to_b26, :to_base26
end

class String
  Base26Values = {}
  Integer::Base26Digits.each_with_index {|c, i| Base26Values[c] = i }
  Base26Values.freeze

  def as_base26_to_i
    raise ArgumentError, 'Invalid base-26 number.' unless self.is_valid_base26?
    value = 0
    position = 0
    self.reverse.upcase.each_char do |c|
      value += 26 ** position * Base26Values[c]
      position += 1
    end
    value
  end

  def is_valid_base26?
    self =~ /\A[a-z]+\Z/i
  end

  alias_method :as_b26_to_i, :as_base26_to_i
  alias_method :is_valid_b26?, :is_valid_base26?
end

if $0 == __FILE__
  require 'test/unit'

  class Base26Test < Test::Unit::TestCase
    def test_to_b26
      assert_equal 'A',   0.to_b26
      assert_equal 'B',   1.to_b26
      assert_equal 'Z',   25.to_b26
      assert_equal 'BA',  26.to_b26
      assert_equal 'BI',  34.to_b26
      assert_equal 'ZZ',  675.to_b26
      assert_equal 'RAINUX', 202133331.to_b26
    end

    def test_as_b26_to_i
      assert_equal 0,     'a'.as_b26_to_i
      assert_equal 0,     'aa'.as_b26_to_i
      assert_equal 1,     'b'.as_b26_to_i
      assert_equal 25,    'z'.as_b26_to_i
      assert_equal 26,    'ba'.as_b26_to_i
      assert_equal 40,    'bo'.as_b26_to_i
      assert_equal 675,   'zz'.as_b26_to_i
      assert_equal 202133331, 'Rainux'.as_b26_to_i
    end

    def test_invalid_b26_string
      assert_raise ArgumentError do
        ' '.as_b26_to_i
      end
      assert_raise ArgumentError do
        ''.as_b26_to_i
      end
      assert_raise ArgumentError do
        '1a'.as_b26_to_i
      end
      assert_raise ArgumentError do
        'b0'.as_b26_to_i
      end
      assert_raise ArgumentError do
        ' a'.as_b26_to_i
      end
    end
  end
end
