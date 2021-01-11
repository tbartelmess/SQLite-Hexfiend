# Hex Fiend template for SQLite databases

This template for [HexFiend][1] allows you to inspect SQLite databases.

This can be useful for doing analysis of storage, exploring and teaching SQLite internals.

The current version implements:

- Database Header
- Pages
- Cells and values on leaf table pages

## Installation and Usage

### Install the Template
You’ll need Hex Fiend 2.9.0 or later, however, this script is only tested with [Hex Fiend 2.14.0][2].

Download the `SQLite.tcl` Script and save it in `~/Library/Application Support/com.ridiculousfish.HexFiend/Templates`

```bash
curl https://raw.githubusercontent.com/tbartelmess/SQLite-Hexfiend/main/SQLite.tcl > ~/Library/Application\ Support/com.ridiculousfish.HexFiend/Templates
```

Open a SQLite file in HexFiend, open the “Binary Template” section (Views-\>Binary Templates) and select “SQLite”.

![Screenshot of HexFiend using the SQLite template][image-1]

[1]:	(http://ridiculousfish.com/hexfiend/
[2]:	https://github.com/HexFiend/HexFiend/releases/tag/v2.14.0

[image-1]:	docs/screenshot.png