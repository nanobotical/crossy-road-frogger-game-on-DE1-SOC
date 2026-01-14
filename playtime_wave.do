onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Playtime_testbench/CLOCK_PERIOD
add wave -noupdate /Playtime_testbench/clk
add wave -noupdate /Playtime_testbench/reset
add wave -noupdate /Playtime_testbench/sprite_grid
add wave -noupdate /Playtime_testbench/spike_grid
add wave -noupdate /Playtime_testbench/score
add wave -noupdate /Playtime_testbench/hit
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {0 ps} {1 ns}
