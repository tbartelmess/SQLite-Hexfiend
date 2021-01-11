# SQLite files are always in Big Endian
big_endian

proc read_sqlite_version {} {
	set start [pos]
	set version_int [uint32]
	set major [expr $version_int / 1000000]
	set version_int [expr $version_int - [expr $major * 1000000]]
	set minor [expr $version_int / 1000]
	set patch [expr $version_int - [expr $minor * 1000]]
	
	entry "SQLite Version" "$major.$minor.$patch" 4 $start
}

proc read_page_flags {} {
	set start [pos]
	set flags [uint8]
	switch $flags {
		2 {
			entry "Page Type" "interior index b-tree page" 1 $start
		}
		5 {
			entry "Page Type" "interior table b-tree page" 1 $start
		}
		10 {
			entry "Page Type" "leaf index b-tree" 1 $start
			return index-btree
		}
		13 {
			entry "Page Type" "leaf table b-tree" 1 $start
			return table-btree
		}
		defaut {
			entry "Page Type" "Invalid" 1 $start
			
		}
	}
}

proc read_varint { {name ""} } {
	set start [pos]
	set seven_bits 0x7F
	set first_bit 0x80
	set value 0
	for { set i 0 } { $i < 10 } { incr i } {
	
		set byte [uint8]
		
		if { $i == 9 } {
			set value [expr [expr $value << 8] | $byte]
			break
		}
		set value [expr [expr $value << 7] | [expr $byte & $seven_bits]]
		if { [expr $byte & $first_bit] == 0 } {
			break
		}
	}
	incr i
	if {$name != ""} {
		entry $name "$value" [expr $i] $start
	}
	return $value
}



proc read_column_type { index } {
	set start [pos]

	set serial_type [read_varint]
	dict set result result_type $serial_type 
	switch $serial_type {
		0 {
			entry "Column $index Type" "NULL" $start [expr [pos] - $start]
			dict set result result_type "null"
		}
		1 {
			entry "Column $index Type" "8-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int8"
		}
		2 {
			entry "Column $index Type" "16-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int16"
		}
		3 {
			entry "Column $index Type" "24-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int24"
		}
		4 {
			entry "Column $index Type" "32-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int32"
		}
		5 {
			entry "Column $index Type" "48-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int48"
		}
		6 {
			entry "Column $index Type" "64-bit int" [expr [pos] - $start ] $start 
			dict set result result_type "int64"
		}
		7 {
			entry "Column Type" "IEEE 754-2008 64-bit" [expr [pos] - $start ] $start 
			dict set result result_type "float64"
		}
		8 {
			entry "Column $index Type" "0" [expr [pos] - $start ] $start 
			dict set result result_type "0"
		}
		9 {
			entry "Column $index Type" "1" [expr [pos] - $start ] $start 
			dict set result result_type "1"
		}
		10 {
			entry "Column $index Type" "INTERNAL" [expr [pos] - $start ] $start 
			dict set result result_type "internal"
		}
		11 {
			entry "Column $index Type" "INTERNAL" [expr [pos] - $start ] $start 
			dict set result result_type "internal"
		}
		default {
			if { $serial_type >= 12 && [expr $serial_type % 2] == 0 } {
				entry "Column $index Type" "BLOB" [expr [pos] - $start ] $start 
				dict set result result_type "blob"
				dict set result length [expr [expr $serial_type - 12] / 2]
			}
			if { $serial_type >= 13 && [expr $serial_type % 2] == 1 } {
				entry "Column $index Type" "Text" [expr [pos] - $start ] $start 
				dict set result result_type "text"
				dict set result length [expr [expr $serial_type - 13] / 2]
			}
			
		}
		
	}
}


proc read_column {column index} {
	puts "Read $column"
	switch [dict get $column result_type] {
		"int8" {
			int8 "Column $index"
		}
		"text" {
			str [dict get $column length] "utf8" "Column $index"
		}
	}
}

section "Database Header" {
	bytes 16 "Magic String"
	set page_size [uint16 "Database Page Size"]
	uint8 "File Format Write Version"
	uint8 "File Format Read Version"
	uint8 "Reserved Bytes"
	uint8 "Maximum embedded payload fraction"
	uint8 "Minimum embedded payload fraction"
	uint8 "Leaf payload fraction"
	uint32 "File change counter"
	set page_count [uint32 "Number of database pages"]
	uint32 "Page number of the first freelist trunk page"
	uint32 "Total number of freelist pages"
	uint32 "The schema cookie"
	uint32 "The schema format number"
	uint32 "Default page cache size"
	uint32 "The page number of the largest root b-tree page when in auto-vacuum or incremental-vacuum modes, or zero otherwise"
	uint32 "Database Text Encoding"
	uint32 "User Version"
	uint32 "Incremental-vacuum mode"
	uint32 "Application ID"
	bytes 20 "Reserved for future expansion"
	uint32 "Valid for Version"
	read_sqlite_version
}

proc read_leaf_table_page { end } {
while { [pos] < $end } {

		set start [pos]
		set size [read_varint "Cell Size"]
		read_varint "Rowid"
		
		section "Record" {
			set header_start [pos]
			set header_size [read_varint "Size"]
			set header_end [expr $header_start + $header_size]
			
			set columns(0) 0
			set column_index 0
			
			while {[pos] < $header_end} {
				set value [read_column_type $column_index]
				set columns($column_index) $value
				incr column_index
			}
			
			for { set index 0 }  { $index < [array size columns] }  { incr index } {
				set column $columns($index)
				read_column $column $index
			}
		}
		unset columns

	}
}

section "Pages" {
	for { set page_no 0 } { $page_no < $page_count } { incr page_no } {
		section "Page $page_no" {
			set page_start [pos]
			set _page_size $page_size
			if { $page_no == 0 } {
				set page_start 0
				set _page_size [expr $page_size - 100]
				entry "Special Page" "Database Root Page"
			}
			set page_type [read_page_flags]
			uint16 "First freeblock"
			uint16 "Number of cells"
			set cell_offset [uint16 "Cell content offset"]
			uint16 "Fragmented free bytes"
			uint16 "Right-most pointer (interior pages only)"
			# Goto to cells
			entry "Page start" $page_start
			goto [expr $page_start + $cell_offset]
			switch $page_type {
				table-btree {
					section "Cells" {
						read_leaf_table_page [expr $page_start + $page_size]
					}
				}
			}
			goto [expr $page_start + $page_size]
		}
	}
}