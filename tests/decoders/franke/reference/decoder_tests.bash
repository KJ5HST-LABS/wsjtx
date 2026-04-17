DECODER_TESTS_VERSION=26.04.15-1

PATH_TO_JT9="/Users/sfranke/Builds/wsjtx-internal/install/wsjtx.app/Contents/MacOS/jt9"
PATH_TO_WSPRD="/Users/sfranke/Builds/wsjtx-internal/install/wsjtx.app/Contents/MacOS/wsprd"
PATH_TO_SOX="/opt/local/bin/sox"
PATH_TO_SAMPLES="/Users/sfranke/Library/Application Support/WSJT-X/save/samples"

echo "**********************************************"
echo "Decoder Tests Version:" $DECODER_TESTS_VERSION
echo "**********************************************"
echo ""

echo "FST4W-1800"
OPTIONS="-p 1800 -W -d 3 -f 1500 -F 100 -q"
FILES="$PATH_TO_SAMPLES/FST4+FST4W/201230_0300.wav"
echo "$FILES"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

echo "FST4-60"
OPTIONS="-p 60 -7 -d 3 -L 900 -H 1400 -q"
FILES="$PATH_TO_SAMPLES/FST4+FST4W/210115_0058.wav"
echo "$FILES"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

#FT4
echo "FT4"
OPTIONS="-5 -d 3 -q"
FILES="$PATH_TO_SAMPLES/FT4/000000_000002.wav"
echo "$FILES"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

#FT8 Standard Decoder
echo "FT8 - standard decoder"
OPTIONS="-8 -d 3 -q"
FILES="$PATH_TO_SAMPLES/FT8/210703_133430.wav"
echo "$FILES"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

#FT8 MT decoder 
echo "FT8 - MT decoder"
OPTIONS="-8 -M -N 1 -E 3 -q"
echo "$FILES"
FILES="$PATH_TO_SAMPLES/FT8/210703_133430.wav"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

#JT4 
echo "JT4"
OPTIONS="-4 -f 1250 -F 50 -b A -p 60 -X 96 -d 3 -q"
FILE1="$PATH_TO_SAMPLES/JT4/JT4A/DF2ZC_070926_040700.wav"
echo "$FILE1"
$PATH_TO_SOX "$FILE1" -b 16 tmp1.wav rate 12000
$PATH_TO_SOX tmp1.wav 000000_0091.wav pad 0 1.0
$PATH_TO_JT9 $OPTIONS 000000_0091.wav

OPTIONS="-4 -f 1200 -F 50 -b F -p 60 -X 96 -d 3 -q"
FILE1="$PATH_TO_SAMPLES/JT4/JT4F/OK1KIR_141105_175700.wav"
echo "$FILE1"
$PATH_TO_SOX "$FILE1" -b 16 tmp1.wav rate 12000
$PATH_TO_SOX tmp1.wav 000000_0092.wav pad 0 1.0
$PATH_TO_JT9 $OPTIONS 000000_0092.wav

rm 000000_00??.wav tmp1.wav
echo ""

#JT9 
echo "JT9"
OPTIONS="-9 -q"
FILES="$PATH_TO_SAMPLES/JT9/130418_1742.wav"
echo "$FILES"
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

#JT65 
echo "JT65B - average odd intervals" 
OPTIONS="-6 -b B -X 96 -d 16 -f 1300 -F 100 -x K1ABC -q"
FILE1="$PATH_TO_SAMPLES/JT65/JT65B/000000_0001.wav"
echo "$FILE1"
FILE2="$PATH_TO_SAMPLES/JT65/JT65B/000000_0003.wav"
echo "$FILE2"
FILE3="$PATH_TO_SAMPLES/JT65/JT65B/000000_0005.wav"
echo "$FILE3"
FILE4="$PATH_TO_SAMPLES/JT65/JT65B/000000_0007.wav"
echo "$FILE4"
$PATH_TO_SOX "$FILE1" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0091.wav pad 0 2.1
$PATH_TO_SOX "$FILE2" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0093.wav pad 0 2.1
$PATH_TO_SOX "$FILE3" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0095.wav pad 0 2.1
$PATH_TO_SOX "$FILE4" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0097.wav pad 0 2.1
$PATH_TO_JT9 $OPTIONS 000000_0091.wav 000000_0093.wav 000000_0095.wav 000000_0097.wav
#$PATH_TO_JT9 $OPTIONS "$FILE1" "$FILE2" "$FILE3" "$FILE4"
rm 000000_00??.wav tmp.wav
echo ""

echo "JT65B - average even intervals" 
OPTIONS="-6 -b B -X 96 -d 16 -f 1700 -F 100 -x G4XYZ -c K1ABC -q"
FILE1="$PATH_TO_SAMPLES/JT65/JT65B/000000_0002.wav"
echo "$FILE1"
FILE2="$PATH_TO_SAMPLES/JT65/JT65B/000000_0004.wav"
echo "$FILE2"
FILE3="$PATH_TO_SAMPLES/JT65/JT65B/000000_0006.wav"
echo "$FILE3"
$PATH_TO_SOX "$FILE1" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0092.wav pad 0 2.1
$PATH_TO_SOX "$FILE2" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0094.wav pad 0 2.1
$PATH_TO_SOX "$FILE3" tmp.wav trim 2.1
$PATH_TO_SOX tmp.wav 000000_0096.wav pad 0 2.1
$PATH_TO_JT9 $OPTIONS 000000_0092.wav 000000_0094.wav 000000_0096.wav
rm 000000_00??.wav tmp.wav
echo ""

echo "JT65B - DL7UAE_040308_002400.wav"
# Should decode as: 0403 -23  3.3 1494 #* K1JT DL7UAE JO62
OPTIONS="-6 -b B -X 96 -d 2 -f 1494 -F 50 -c K1JT -x DL7UAE -q"
FILE1="$PATH_TO_SAMPLES/JT65/JT65B/DL7UAE_040308_002400.wav"
echo "$FILE1"
$PATH_TO_SOX "$FILE1" -b 16 tmp1.wav rate 12000
$PATH_TO_SOX tmp1.wav tmp2.wav pad 0 3.0
$PATH_TO_SOX tmp2.wav 000000_0091.wav trim 3.0
$PATH_TO_JT9 $OPTIONS 000000_0091.wav
rm 000000_00??.wav tmp1.wav tmp2.wav
echo ""

#MSK144
echo "Decode MSK144"
OPTIONS="-k -p 15 -q"
FILE1="$PATH_TO_SAMPLES"/MSK144/181211_120500.wav
echo "$FILE1"
$PATH_TO_JT9 $OPTIONS "$FILE1"
FILE1="$PATH_TO_SAMPLES"/MSK144/181211_120800.wav
echo "$FILE1"
$PATH_TO_JT9 $OPTIONS "$FILE1"
echo ""

#Q65A
echo "Q65-30A 3-file averages"
FILE1="$PATH_TO_SAMPLES"/Q65/30A_Ionoscatter_6m/201203_022700.wav
echo "$FILE1"
FILE2="$PATH_TO_SAMPLES"/Q65/30A_Ionoscatter_6m/201203_022800.wav
echo "$FILE2"
FILE3="$PATH_TO_SAMPLES"/Q65/30A_Ionoscatter_6m/201203_022900.wav
echo "$FILE3"
FILE4="$PATH_TO_SAMPLES"/Q65/30A_Ionoscatter_6m/201203_024000.wav
echo "$FILE4"

echo ""
echo "3-file averages:"
OPTIONS="-3 -b A -p 30 -X 96 -f 1000 -F 20 -q"
echo "1,2,3"
$PATH_TO_JT9 $OPTIONS "$FILE1" "$FILE2" "$FILE3"
echo "1,2,4"
$PATH_TO_JT9 $OPTIONS "$FILE1" "$FILE2" "$FILE4"
echo "1,3,4"
$PATH_TO_JT9 $OPTIONS "$FILE1" "$FILE3" "$FILE4"
echo "2,3,4"
$PATH_TO_JT9 $OPTIONS "$FILE2" "$FILE3" "$FILE4"
echo ""
echo "Single file decodes with AP:"
OPTIONS="-3 -b A -p 30 -X 96 -f 1000 -F 20 -x K9AN -c K1JT -Q 1 -q"
$PATH_TO_JT9 $OPTIONS "$FILE1" 
$PATH_TO_JT9 $OPTIONS "$FILE2" 
$PATH_TO_JT9 $OPTIONS "$FILE3" 
$PATH_TO_JT9 $OPTIONS "$FILE4" 
echo ""

echo "Q65-60A 6m EME"
#OPTIONS="-3 -b A -p 60 -X 96 -f 1500 -F 100 -q"
OPTIONS="-3 -b A -p 60 -f 1500 -F 100 -q"
FILE1="$PATH_TO_SAMPLES"/Q65/60A_EME_6m/210106_1621.wav
echo "$FILE1"
$PATH_TO_SOX "$FILE1" tmp1.wav trim 2.5
$PATH_TO_SOX tmp1.wav 000000_0091.wav pad 0 2.5
$PATH_TO_JT9 $OPTIONS 000000_0091.wav
rm tmp1.wav 000000_00??.wav
echo ""

echo "Q65-60B 1296 Tropo"
FILE1="$PATH_TO_SAMPLES"/Q65/60B_1296_Troposcatter/210109_0007.wav
echo $FILE1
FILE2="$PATH_TO_SAMPLES"/Q65/60B_1296_Troposcatter/210109_0147.wav
echo $FILE2
FILE3="$PATH_TO_SAMPLES"/Q65/60B_1296_Troposcatter/210109_0151.wav
echo $FILE3
echo ""
echo "Single file decodes with AP:"
OPTIONS="-3 -b B -p 60 -f 1000 -F 20 -d 3 -c VK7MO -x VK7PD -Q 1 -q"
$PATH_TO_JT9 $OPTIONS "$FILE1" 
$PATH_TO_JT9 $OPTIONS "$FILE2"
$PATH_TO_JT9 $OPTIONS "$FILE3"
echo ""
echo "3-file average:"
OPTIONS="-3 -b B -p 60 -f 1000 -F 20 -d 3 -q"
$PATH_TO_JT9 $OPTIONS "$FILE1" "$FILE2" "$FILE3"
echo ""

echo "Q65-60D EME 10GHz"
OPTIONS="-3 -b D -p 60 -X 96 -f 1000 -F 100 -q"
FILE1="$PATH_TO_SAMPLES"/Q65/60D_EME_10GHz/201212_1838.wav
echo "$FILE1"
$PATH_TO_SOX "$FILE1" tmp1.wav trim 2.5
$PATH_TO_SOX tmp1.wav 000000_0091.wav pad 0 2.5
$PATH_TO_JT9 $OPTIONS 000000_0091.wav
rm tmp1.wav 000000_00??.wav
echo ""

echo "Q65-120D 10 GHz Rainscatter"
OPTIONS="-3 -b D -p 120 -X 96 -f 1000 -F 20 -d 3 -q"
FILES="$PATH_TO_SAMPLES"/Q65/120D_Rainscatter_10_GHz/210117_0920.wav
echo $FILES
$PATH_TO_JT9 $OPTIONS "$FILES"
echo ""

echo "Q65-120E 6m Ionoscatter"
OPTIONS="-3 -b E -p 120 -X 96 -f 1800 -F 20 -d 3 -x N0AN -c KB7IJ -Q 4 -q"
FILE1="$PATH_TO_SAMPLES"/Q65/120E_Ionoscatter_6m/210130_1438.wav
echo $FILE1
FILE2="$PATH_TO_SAMPLES"/Q65/120E_Ionoscatter_6m/210130_1442.wav
echo $FILE2
$PATH_TO_JT9 $OPTIONS "$FILE1" 
#OPTIONS="-3 -b E -p 120 -X 96 -f 1800 -F 20 -d 3 -q"
$PATH_TO_JT9 $OPTIONS "$FILE2"
echo ""

echo "Q65-300A Optical Scatter"
OPTIONS="-3 -b A -p 300 -X 96 -f 1000 -F 20 -d 3 -q"
FILE1="$PATH_TO_SAMPLES"/Q65/300A_Optical_Scatter/201210_0505.wav
echo $FILE1
$PATH_TO_JT9 $OPTIONS "$FILE1"
echo ""

#WSPR
echo "WSPR"
OPTIONS="-d -C 500 -o 4"
FILE1="$PATH_TO_SAMPLES"/WSPR/150426_0918.wav
echo "$FILE1"
$PATH_TO_WSPRD $OPTIONS "$FILE1"
echo ""
