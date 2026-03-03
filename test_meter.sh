#!/bin/bash
# Test waveform metering: reproduces exactly what whisper.lua does.
# Run: bash ~/.hammerspoon/test_meter.sh
# Speak into the mic — you should see the level bar move.

METER_FILE="/tmp/test_meter.raw"
SOX="/opt/homebrew/bin/sox"

rm -f "$METER_FILE"

# Start sox — same args as whisper.lua
"$SOX" --buffer 800 -d -t raw -r 8000 -c 1 -e unsigned-integer -b 8 "$METER_FILE" 2>/dev/null &
SOX_PID=$!
echo "Sox PID: $SOX_PID — recording for 6 seconds, speak now..."
echo ""

OFFSET=0

for i in $(seq 1 24); do
    sleep 0.25

    SIZE=$(stat -f%z "$METER_FILE" 2>/dev/null || echo 0)
    NEW=$((SIZE - OFFSET))

    if [ "$NEW" -gt 0 ]; then
        python3 - "$METER_FILE" "$OFFSET" "$SIZE" <<'PYEOF'
import sys, math

path, offset, size = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with open(path, "rb") as f:
    f.seek(offset)
    data = f.read(size - offset)

samples = [b - 128 for b in data]
gain = 20
rms = min(1.0, math.sqrt(sum(s * s for s in samples) / len(samples)) / 128 * gain)
bar = "█" * int(rms * 50)
print(f"  rms={rms:.4f}  |{bar:<50}|  ({len(data)} bytes)")
PYEOF
        OFFSET=$SIZE
    else
        echo "  (no new data — file size=$SIZE offset=$OFFSET)"
    fi
done

kill "$SOX_PID" 2>/dev/null
rm -f "$METER_FILE"
echo ""
echo "Done."
