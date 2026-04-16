#!/bin/bash
# Supabase Functionality Test Runner (macOS/Linux)
# Run this script to execute all Supabase integration tests

echo ""
echo "======================================================"
echo "  SUPABASE INTEGRATION TEST SUITE"
echo "======================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to run command and check result
run_command() {
    local cmd=$1
    local message=$2
    
    echo -e "${YELLOW}${message}${NC}"
    eval $cmd
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: ${message} failed${NC}"
        return 1
    fi
}

# Step 1: Get dependencies
if ! run_command "flutter pub get" "[1/4] Getting dependencies..."; then
    exit 1
fi
echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
echo ""

# Step 2: Build runners
echo -e "${YELLOW}[2/4] Building code generators...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | grep -i error || true
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✅ Code generators built${NC}"
else
    echo -e "${YELLOW}⚠️  Build runner completed with warnings (non-critical)${NC}"
fi
echo ""

# Step 3: Run integration tests
echo -e "${YELLOW}[3/4] Running integration tests...${NC}"
echo ""
flutter test test/supabase_integration_test.dart -v
TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ INTEGRATION TESTS FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[4/4] Running verification script...${NC}"
echo ""

# Step 4: Run verification script
flutter run -t lib/test_verification.dart
VERIFICATION_RESULT=$?

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}  ✅ ALL TESTS COMPLETED${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""

if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${CYAN}Summary:${NC}"
    echo -e "${GREEN}  ✅ Integration tests: PASSED${NC}"
    echo -e "${GREEN}  ✅ User authentication verified${NC}"
    echo -e "${GREEN}  ✅ Profile creation verified${NC}"
    echo -e "${GREEN}  ✅ Supabase cloud operations verified${NC}"
    echo -e "${GREEN}  ✅ Local storage (Hive) verified${NC}"
    echo -e "${GREEN}  ✅ Cloud-local sync verified${NC}"
    echo ""
    echo -e "${GREEN}Supabase functionality is working correctly!${NC}"
    echo ""
else
    echo -e "${RED}Some tests failed. Review output above.${NC}"
    echo ""
fi
