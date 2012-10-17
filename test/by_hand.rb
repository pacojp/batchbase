
# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'

require 'batch_by_hand'

b = BatchByHand.new
b.set_signal_observer(:receive_signal)
b.proceed



