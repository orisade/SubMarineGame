#!/bin/bash

echo "Running submarine game simulation..."
make clean
make

if [ $? -eq 0 ]; then
    echo "✅ Simulation completed successfully!"
    echo "📊 VCD file generated: submarine_tb.vcd"
    echo "🔍 To view waveforms: make wave"
else
    echo "❌ Simulation failed!"
    exit 1
fi
