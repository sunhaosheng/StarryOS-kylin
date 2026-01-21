#!/bin/bash
#
# StarryOS CI Test Results Parser
# 解析 QEMU 测试输出并生成摘要
#
# 使用方法：
#   ./parse-test-results.sh <log_file>
#
# 退出码：
#   0 - 所有测试通过
#   1 - 有测试失败
#   2 - 无法解析结果
#

set -e

LOG_FILE="${1:-/results/qemu-output.log}"

echo "========================================"
echo "StarryOS CI Test Results"
echo "========================================"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Error: Log file not found: $LOG_FILE"
    exit 2
fi

echo "Log file: $LOG_FILE"
echo "Log size: $(wc -c < "$LOG_FILE") bytes"
echo ""

# 检查是否有内核 panic
if grep -q "Kernel panic" "$LOG_FILE"; then
    echo "❌ CRITICAL: Kernel panic detected!"
    echo ""
    echo "=== Panic Message ==="
    grep -A 20 "Kernel panic" "$LOG_FILE" | head -25
    exit 1
fi

# 检查是否成功启动
if ! grep -q "root@starry" "$LOG_FILE"; then
    echo "❌ Error: System did not boot successfully"
    echo ""
    echo "=== Last 30 lines of log ==="
    tail -30 "$LOG_FILE"
    exit 2
fi

echo "✓ System booted successfully"
echo ""

# 解析测试结果
echo "=== Test Results ==="

if grep -q "Test Results Summary" "$LOG_FILE"; then
    # 提取测试摘要
    grep -A 15 "Test Results Summary" "$LOG_FILE" | head -20
    echo ""
    
    # 统计
    PASSED=$(grep -oP "Passed:\s*\K\d+" "$LOG_FILE" | tail -1 || echo "?")
    FAILED=$(grep -oP "Failed:\s*\K\d+" "$LOG_FILE" | tail -1 || echo "?")
    SKIPPED=$(grep -oP "Skipped:\s*\K\d+" "$LOG_FILE" | tail -1 || echo "0")
    
    echo "=== Summary ==="
    echo "  Passed:  $PASSED"
    echo "  Failed:  $FAILED"
    echo "  Skipped: $SKIPPED"
    echo ""
    
    # 检查是否有失败
    if [ "$FAILED" = "0" ]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ $FAILED test(s) failed"
        echo ""
        
        # 显示失败的测试详情
        echo "=== Failed Tests ==="
        grep -B 2 -A 5 "✗\|FAIL\|Error:" "$LOG_FILE" | head -50 || true
        exit 1
    fi
else
    # 尝试其他格式
    if grep -q "All tests passed" "$LOG_FILE"; then
        echo "✅ All tests passed!"
        exit 0
    elif grep -q "FAILED" "$LOG_FILE"; then
        echo "❌ Some tests failed"
        echo ""
        echo "=== Test Output ==="
        grep -B 2 -A 5 "FAILED\|Error" "$LOG_FILE" | head -50 || true
        exit 1
    else
        echo "⚠️ Could not parse test results"
        echo ""
        echo "=== Raw Output (last 50 lines) ==="
        tail -50 "$LOG_FILE"
        exit 2
    fi
fi
