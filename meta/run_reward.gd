class_name RunReward
extends RefCounted
## What SaveData.bank_run() did with a finished run, for the run summary.

var coins_banked := 0
var total_coins := 0
var new_best_time := false
var new_unlocks: Array[CharacterData] = []
