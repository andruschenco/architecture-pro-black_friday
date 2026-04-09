#!/bin/bash

URL="http://localhost:8089/users/users"

echo "=== Cache Speed Test ==="

# First request
echo -e "\n1. First request (without cache):"
time curl -s -o /dev/null -w "   Time: %{time_total}s (%{time_total}000 ms)\n" "$URL"

# Second request
echo -e "\n2. Second request (with cache):"
time curl -s -o /dev/null -w "   Time: %{time_total}s (%{time_total}000 ms)\n" "$URL"

# Third request
echo -e "\n3. Third request (with cache):"
time curl -s -o /dev/null -w "   Time: %{time_total}s (%{time_total}000 ms)\n" "$URL"

echo -e "\n=== Done ==="