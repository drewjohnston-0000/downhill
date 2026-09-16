extends GdUnitTestSuite
## Unit tests for the pure list maths of BestTimes (no disk).


func test_merged_sorts_ascending_and_caps() -> void:
	var out := BestTimes.merged([50.0, 40.0], 45.0, 5)
	assert_array(out).is_equal([40.0, 45.0, 50.0])


func test_merged_keeps_only_the_fastest_n() -> void:
	var out := BestTimes.merged([30.0, 40.0, 50.0], 20.0, 3)
	assert_array(out).is_equal([20.0, 30.0, 40.0])  # 50.0 dropped


func test_is_new_best() -> void:
	var bt := BestTimes.new(false)  # don't load from disk
	assert_bool(bt.is_new_best(42.0)).is_true()  # nothing recorded yet
	bt.times = [40.0, 45.0]
	assert_bool(bt.is_new_best(39.9)).is_true()
	assert_bool(bt.is_new_best(40.1)).is_false()


func test_best_and_has_any() -> void:
	var bt := BestTimes.new(false)
	assert_bool(bt.has_any()).is_false()
	assert_float(bt.best()).is_equal(-1.0)
	bt.times = [40.0, 45.0]
	assert_bool(bt.has_any()).is_true()
	assert_float(bt.best()).is_equal(40.0)
