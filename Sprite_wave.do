onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Sprite_testbench/CLOCK_PERIOD
add wave -noupdate /Sprite_testbench/reset
add wave -noupdate /Sprite_testbench/move_up
add wave -noupdate /Sprite_testbench/move_down
add wave -noupdate /Sprite_testbench/move_left
add wave -noupdate /Sprite_testbench/move_right
add wave -noupdate -expand /Sprite_testbench/grid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {4658 ps}
