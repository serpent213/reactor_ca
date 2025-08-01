#  ______                                    ______
# (_____ \                  _               / _____)  /\
#  _____) ) ____ ____  ____| |_  ___   ____| /       /  \
# (_____ ( / _  ) _  |/ ___)  _)/ _ \ / ___) |      / /\ \
#       | ( (/ ( ( | ( (___| |_| |_| | |   | \_____| |__| |
#       |_|\____)_||_|\____)\___)___/|_|    \______)______|

version := "0.5.0"
dirs := "./cmd ./internal ./test"
packages := "./cmd/... ./internal/..."

# Show available commands
help:
    @just --list

# Compile binary (debug or release)
build mode="debug":
    #!/usr/bin/env bash
    set -e

    # Copy embedded schema files
    go generate ./internal/infra/config

    version_string="{{version}}"

    # Add unstable suffix if current commit doesn't have a semver release tag
    if ! git tag --points-at HEAD 2>/dev/null | grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+$'; then
        commit_hash=$(git rev-parse --short=6 HEAD)
        version_string="${version_string}-unstable-${commit_hash}"
    fi

    if [[ "{{mode}}" =~ ^r ]]; then # release
        go build -ldflags="-s -w -X main.version=${version_string}" -v ./cmd/ca
    else
        go build -ldflags="-X main.version=${version_string}-debug" -v ./cmd/ca
    fi

# Cross-compile for multiple platforms
build-cross platform="all":
    #!/usr/bin/env bash
    set -e
    mkdir -p dist

    # Copy embedded schema files
    go generate ./internal/infra/config

    version_string="{{version}}"

    # Add unstable suffix if current commit doesn't have a semver release tag
    if ! git tag --points-at HEAD 2>/dev/null | grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+$'; then
        commit_hash=$(git rev-parse --short=6 HEAD)
        version_string="${version_string}-unstable-${commit_hash}"
    fi

    if [ "{{platform}}" = "all" ] || [ "{{platform}}" = "linux" ]; then
        echo "Building for Linux x86_64..."
        GOOS=linux GOARCH=amd64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-linux-amd64 ./cmd/ca
        echo "Building for Linux ARM64..."
        GOOS=linux GOARCH=arm64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-linux-arm64 ./cmd/ca
    fi

    if [ "{{platform}}" = "all" ] || [ "{{platform}}" = "darwin" ]; then
        echo "Building for macOS x86_64..."
        GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-darwin-amd64 ./cmd/ca
        echo "Building for macOS ARM64..."
        GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-darwin-arm64 ./cmd/ca
    fi

    if [ "{{platform}}" = "all" ] || [ "{{platform}}" = "windows" ]; then
        echo "Building for Windows x86_64..."
        GOOS=windows GOARCH=amd64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-windows-amd64.exe ./cmd/ca
        echo "Building for Windows ARM64..."
        GOOS=windows GOARCH=arm64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-windows-arm64.exe ./cmd/ca
    fi

    if [ "{{platform}}" = "all" ] || [ "{{platform}}" = "freebsd" ]; then
        echo "Building for FreeBSD x86_64..."
        GOOS=freebsd GOARCH=amd64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-freebsd-amd64 ./cmd/ca
        echo "Building for FreeBSD ARM64..."
        GOOS=freebsd GOARCH=arm64 go build -ldflags="-s -w -X main.version=${version_string}" -o dist/reactor-ca-freebsd-arm64 ./cmd/ca
    fi

# Build using Nix
build-nix:
    nix build

# Build debug binary
debug: (build "debug")

# Build release binary
release: (build "release")

# Format Go, YAML, JSON schemas, and Nix files
fmt:
    gofmt -s -w {{dirs}}
    go tool yamlfmt -quiet example_config/ .github/
    @just fmt-schemas
    nixfmt *.nix

# Check code formatting
fmt-check:
    @echo "Checking Go formatting..."
    @if [ -n "$(gofmt -s -l {{dirs}})" ]; then \
        echo "Code is not formatted. Run 'just fmt' to fix."; \
        gofmt -s -l {{dirs}}; \
        exit 1; \
    fi
    @echo "Checking YAML formatting..."
    @if ! go tool yamlfmt -lint -quiet example_config/ .github/; then \
        echo "YAML files are not formatted. Run 'just fmt' to fix."; \
        exit 1; \
    fi
    @echo "Checking JSON schema formatting..."
    @just fmt-schemas-check

# Run Go vet analysis
vet:
    go generate ./internal/infra/config
    go vet {{packages}}

# Run staticcheck linter
staticcheck:
    go tool staticcheck {{packages}}

# Run all linting checks
lint: fmt-check vet staticcheck validate-schemas

# Run tests (unit, integration, e2e, or all)
test type="all":
    #!/usr/bin/env bash
    set -e

    # Copy embedded schema files
    go generate ./internal/infra/config

    if [[ "{{type}}" =~ ^u ]]; then # unit
        go test -v ./cmd/... ./internal/...
    elif [[ "{{type}}" =~ ^i ]]; then # integration
        go test -v -tags integration ./test/integration/...
    elif [[ "{{type}}" =~ ^e ]]; then # e2e
        go test -v -tags e2e ./test/e2e/...
    elif [[ "{{type}}" =~ ^b ]]; then # browser
        go test -v -tags browser ./test/e2e/... -timeout=10m
    elif [[ "{{type}}" =~ ^a ]]; then # all
        echo "Running unit tests..."
        just test unit
        echo "Running integration tests..."
        just test integration
        echo "Running e2e tests..."
        just test e2e
    else
        echo "Invalid test type: {{type}}. Use 'unit', 'integration', 'e2e', 'browser', or 'all'."
        exit 1
    fi

# Clear test cache and run tests
retest type="all":
    go clean -testcache
    @just test {{type}}

# Generate test coverage reports
cov type="all":
    #!/usr/bin/env bash
    set -e
    mkdir -p coverage
    go clean -testcache

    # Copy embedded schema files
    go generate ./internal/infra/config

    if [[ "{{type}}" =~ ^u ]]; then # unit
        # Run unit tests with traditional text coverage profile
        go test -coverprofile=coverage/unit.out -covermode=atomic ./cmd/... ./internal/...
        # Filter to only reactor.de/reactor-ca packages, excluding testutil
        (echo "mode: atomic"; grep "reactor.de/reactor-ca" coverage/unit.out | grep -v 'internal/testutil/') > coverage/unit.filtered.out
        mv coverage/unit.filtered.out coverage/unit.out
        go tool cover -html=coverage/unit.out -o coverage/unit.html
        go tool cover -func=coverage/unit.out | tail -1 | sed -E 's/\s+/ /g'
    elif [[ "{{type}}" =~ ^i ]]; then # integration
        # Run integration tests with traditional text coverage profile
        go test -coverprofile=coverage/integration.out -covermode=atomic -tags integration -coverpkg=./cmd/...,./internal/... ./test/integration/...
        # Filter to only reactor.de/reactor-ca packages, excluding testutil
        (echo "mode: atomic"; grep "reactor.de/reactor-ca" coverage/integration.out | grep -v 'internal/testutil/') > coverage/integration.filtered.out
        mv coverage/integration.filtered.out coverage/integration.out
        go tool cover -html=coverage/integration.out -o coverage/integration.html
        go tool cover -func=coverage/integration.out | tail -1 | sed -E 's/\s+/ /g'
    elif [[ "{{type}}" =~ ^e ]]; then # e2e
        # Clean up any existing e2e coverage data
        rm -rf coverage/e2e-covdata
        # Run e2e tests (they will collect coverage via GOCOVERDIR)
        go test -v -tags e2e ./test/e2e/...
        # Convert binary coverage data to profile format
        go tool covdata textfmt -i=coverage/e2e-covdata -o coverage/e2e.out
        # Filter to only reactor.de/reactor-ca packages, excluding testutil
        (echo "mode: atomic"; grep "reactor.de/reactor-ca" coverage/e2e.out | grep -v 'internal/testutil/') > coverage/e2e.filtered.out
        mv coverage/e2e.filtered.out coverage/e2e.out
        go tool cover -html=coverage/e2e.out -o coverage/e2e.html
        go tool cover -func=coverage/e2e.out | tail -1 | sed -E 's/\s+/ /g'
    elif [[ "{{type}}" =~ ^a ]]; then # all
        echo "Running unit tests with coverage..."
        just cov unit
        echo "Running integration tests with coverage..."
        just cov integration
        echo "Running e2e tests with coverage..."
        just cov e2e

        # Merge coverage profiles using proper deduplication
        echo "Merging coverage data..."
        echo "mode: atomic" > coverage/merged.out

        # Combine all coverage entries, handling duplicates properly
        cat coverage/unit.out coverage/integration.out coverage/e2e.out | \
        grep -v "^mode:" | \
        sort -k1,1 -k2,2n | \
        awk '
        {
            # Key is file:start.line,start.col,end.line,end.col
            key = $1 ":" $2
            if (key in seen) {
                # For duplicate entries, use max count (any test that hit it)
                if ($3 > seen[key]) seen[key] = $3
            } else {
                seen[key] = $3
                order[++n] = key
                lines[key] = $1 " " $2
            }
        }
        END {
            for (i = 1; i <= n; i++) {
                key = order[i]
                print lines[key], seen[key]
            }
        }' >> coverage/merged.out

        # Generate HTML report and show summary
        go tool cover -html=coverage/merged.out -o coverage/merged.html
        echo "=== Total Coverage ==="
        go tool cover -func=coverage/merged.out | tail -1 | sed -E 's/\s+/ /g'

        # Generate coverage badge data
        just cov-badge
    else
        echo "Invalid coverage type: {{type}}. Use 'unit', 'integration', 'e2e', or 'all'."
        exit 1
    fi

# Generate coverage badge
cov-badge:
    #!/usr/bin/env bash
    set -e
    if [ ! -f coverage/merged.out ]; then
        echo "No merged coverage file found. Run 'just coverage all' first."
        exit 1
    fi

    # Extract total coverage percentage (already filtered to reactor.de/reactor-ca only)
    coverage_percent=$(go tool cover -func=coverage/merged.out | tail -1 | awk '{print $3}' | sed 's/%//')

    # Generate badge URL
    color="red"
    if (( $(echo "$coverage_percent >= 80" | bc -l) )); then
        color="brightgreen"
    elif (( $(echo "$coverage_percent >= 60" | bc -l) )); then
        color="yellow"
    elif (( $(echo "$coverage_percent >= 40" | bc -l) )); then
        color="orange"
    fi

    echo "Coverage: ${coverage_percent}%"

    # Update README.md with new coverage badge
    badge_url="https://img.shields.io/badge/Coverage-${coverage_percent}%25-${color}"
    sed -i "s|!\[Coverage\](https://img.shields.io/badge/[^)]*)|![Coverage](${badge_url})|" README.md
    echo "Updated README.md with new coverage badge"

# Complete validation pipeline
check: lint build tidy retest build-nix

# CI/CD pipeline
ci: lint tidy test release

# Clean up Go modules
tidy:
    go mod tidy

# Update dependencies and flake
update:
    go get -u ./...
    go mod tidy
    @just update-flake

# Update Nix flake vendor hash
update-flake:
    #!/usr/bin/env bash
    set -e
    echo "Updating vendor hash in flake.nix..."

    sed -i.bak 's/vendorHash = ".*";/vendorHash = pkgs.lib.fakeHash;/' flake.nix

    if output=$(nix build .#reactor-ca 2>&1); then
        echo "Build succeeded unexpectedly. No hash update needed."
        # Restore original if build succeeded
        mv flake.nix.bak flake.nix
    else
        correct_hash=$(echo "$output" | grep "got:" | grep -o 'sha256-[A-Za-z0-9+/]\{43\}=')
        if [ -n "$correct_hash" ]; then
            echo "Found correct hash: $correct_hash"
            sed -i "s|vendorHash = pkgs.lib.fakeHash;|vendorHash = \"$correct_hash\";|" flake.nix
            echo "Updated vendorHash in flake.nix"
            rm -f flake.nix.bak

            echo "Verifying build with new hash..."
            if nix build .#reactor-ca; then
                echo "Build successful with updated vendor hash"
            else
                echo "Build still failing after hash update"
                exit 1
            fi
        else
            echo "Could not extract vendor hash from build output"
            echo "Build output:"
            echo "$output"
            # Restore original on failure
            mv flake.nix.bak flake.nix
            exit 1
        fi
    fi

# Update README.md TOC
update-toc:
    #!/usr/bin/env bash
    set -e

    toc_content=$(
      gh-md-toc --hide-header --hide-footer --start-depth=1 --no-escape README.md \
      | grep -v '#table-of-contents'
    )

    awk -v toc="$toc_content" '
        BEGIN { in_toc = 0; printed_toc = 0 }
        /^## Table of Contents$/ {
            print $0
            print ""
            print toc
            in_toc = 1
            printed_toc = 1
            next
        }
        /^## / && in_toc {
            in_toc = 0
            print ""
            print $0
            next
        }
        !in_toc || !printed_toc { print }
    ' README.md > README.md.tmp
    mv README.md.tmp README.md

    echo "Updated TOC in README.md"

# Update documentation (incl. coverage badge)
docs: cov update-toc

# Format JSON schema files
fmt-schemas:
    #!/usr/bin/env bash
    set -e
    for file in schemas/v1/*.json; do
        if [ -f "$file" ]; then
            jq '.' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
            echo "Formatted: $file"
        fi
    done

# Check JSON schema formatting
fmt-schemas-check:
    #!/usr/bin/env bash
    set -e
    for file in schemas/v1/*.json; do
        if [ -f "$file" ]; then
            if ! jq '.' "$file" > /dev/null 2>&1; then
                echo "Invalid JSON in: $file"
                exit 1
            fi
            if ! cmp -s "$file" <(jq '.' "$file"); then
                echo "Schema not formatted: $file"
                echo "Run 'just fmt-schemas' to fix."
                exit 1
            fi
        fi
    done

# Validate example configs against schemas
validate-schemas:
    #!/usr/bin/env bash
    set -e
    echo "Validating example configs against schemas..."

    if [ -d "example_config" ]; then
        # Collect CA config files
        ca_configs=()
        for config in example_config/ca*.yaml example_config/ca*.yml; do
            if [ -f "$config" ]; then
                ca_configs+=("$config")
            fi
        done

        # Collect hosts config files
        hosts_configs=()
        for config in example_config/hosts.yaml example_config/hosts.yml; do
            if [ -f "$config" ]; then
                hosts_configs+=("$config")
            fi
        done

        # Validate CA configs (grouped)
        if [ ${#ca_configs[@]} -gt 0 ]; then
            go tool jv --assert-content --assert-format schemas/v1/ca.schema.json "${ca_configs[@]}" | \
            grep -vE '^(schema schemas/v1/.*\.schema\.json: ok|)$'
        fi

        # Validate hosts configs (grouped)
        if [ ${#hosts_configs[@]} -gt 0 ]; then
            go tool jv --assert-content --assert-format schemas/v1/hosts.schema.json "${hosts_configs[@]}" | \
            grep -vE '^(schema schemas/v1/.*\.schema\.json: ok|)$'
        fi
    else
        echo "No example_config directory found"
    fi

# Download browser test artifacts, combine with local, update README
update-browser-matrix mode="local":
    #!/usr/bin/env bash
    set -e

    # Browser whitelists - control which browsers are included in the table
    local_browsers=("firefox")
    ci_browsers=("firefox" "chromium" "webkit" "curl")

    # Algorithm ordering - control the order of certificate rows
    algo_order=("RSA" "ECP" "ED")

    if [[ "{{mode}}" =~ ^d ]]; then # download
        echo "Downloading browser test artifacts..."

        run_id=$(gh run list -w "Browser Test" -L 1 --json databaseId --jq '.[0].databaseId')
        echo "Latest Browser Test run: $run_id"

        rm -rf tmp/browser-artifacts
        mkdir -p tmp/browser-artifacts
        cd tmp/browser-artifacts
        gh run download "$run_id"

        echo "Processing artifacts..."

        echo "Combining JSON files..."
        mkdir -p ../../docs

        jq -s '
        {
          metadata: {
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            browsers: (reduce .[] as $file ({}; .[$file.browser] = $file.version // "unknown"))
          },
          results: [.[] as $file | $file.results[] | {browser: $file.browser, certificate: .certificate, status: .status}]
        }' */*-results.json > ../../docs/browser-matrix-ci.json

        cd ../..
    else
        echo "Skipping download, using existing artifacts..."
        if [ ! -f "docs/browser-matrix-ci.json" ]; then
            echo "Warning: No existing CI results found at docs/browser-matrix-ci.json"
        fi
    fi

    echo "Converting to markdown table..."

    # Generate markdown table with browsers as columns and cert combos as rows
    ci_data='{}'
    local_data='{}'
    if [ -f "docs/browser-matrix-ci.json" ]; then
        ci_data=$(cat docs/browser-matrix-ci.json)
    fi
    if [ -f "docs/browser-matrix-local.json" ]; then
        local_data=$(cat docs/browser-matrix-local.json)
    fi

    full_table=$(jq -rn --argjson ci "$ci_data" --argjson local "$local_data" \
        --argjson local_browsers "$(printf '%s\n' "${local_browsers[@]}" | jq -R . | jq -s .)" \
        --argjson ci_browsers "$(printf '%s\n' "${ci_browsers[@]}" | jq -R . | jq -s .)" \
        --argjson algo_order "$(printf '%s\n' "${algo_order[@]}" | jq -R . | jq -s .)" '
        # Helper function to format status with colors
        def format_status: if . == "PASS" then "🟢 PASS" elif . == "FAIL" then "🔴 FAIL" else . end;

        # Helper function to truncate version to major.minor
        def truncate_version: if . == "unknown" then . else split(".") | .[0:2] | join(".") end;

        # Helper function to capitalize first letter only
        def capitalize: (.[0:1] | ascii_upcase) + (.[1:] | ascii_downcase);

        # Create lookup tables for easy access: {cert: {browser: status}}
        def create_lookup(data):
            (data.results // []) | group_by(.certificate) |
            map(.[0].certificate as $cert | {($cert): (group_by(.browser) | map({(.[0].browser): .[0].status}) | add)}) | add;

        # Get all unique certificates from both datasets, sorted by algorithm order
        def get_certificates:
            [($ci.results // [])[], ($local.results // [])[]] |
            map(.certificate) | unique |
            sort_by(
                # Create sort key based on algorithm order, then by full certificate name
                . as $cert |
                ($algo_order | map(. as $algo | if ($cert | ascii_upcase | startswith($algo)) then ($algo_order | to_entries | map(select(.value == $algo))[0].key) else 999 end) | min) * 1000 +
                # Secondary sort by the certificate string itself for stable ordering within algorithm groups
                ($cert | length)
            );

        # Create lookup tables and variables
        get_certificates as $certs |
        create_lookup($ci) as $ci_lookup |
        create_lookup($local) as $local_lookup |

        # Generate dynamic headers: Key/Signature + Local browsers + CI browsers
        (["Key/Signature"] +
         [$local_browsers[] as $browser | ($browser | capitalize) + "<br>" + (($local.metadata.browsers[$browser] // "unknown") | truncate_version) + "-macOS"] +
         [$ci_browsers[] as $browser | ($browser | capitalize) + "<br>" + (($ci.metadata.browsers[$browser] // "unknown") | truncate_version) + "-CI"] | @tsv),
        (["---"] + [range(($local_browsers | length) + ($ci_browsers | length)) | "---"] | @tsv),

        # Generate data rows with dynamic columns
        ($certs[] as $cert |
            [($cert | ascii_upcase)] +
            [$local_browsers[] | ($local_lookup[$cert][.] // "N/A") | format_status] +
            [$ci_browsers[] | ($ci_lookup[$cert][.] // "N/A") | format_status]
            | @tsv
        ) | gsub("\t"; " | ") | "| " + . + " |"
    ')

    awk -v table="$full_table" '
        BEGIN { in_matrix = 0; printed_table = 0; skip_table = 0 }
        /^## Browser Compatibility Matrix$/ {
            print $0
            print ""
            print table
            print ""
            in_matrix = 1
            printed_table = 1
            skip_table = 1
            next
        }
        /^## / && in_matrix {
            in_matrix = 0
            skip_table = 0
        }
        # Skip table content (lines starting with | or ---)
        skip_table && (/^[[:space:]]*\|/ || /^[[:space:]]*[-|[:space:]]+$/) { next }
        # Skip empty lines immediately after table
        skip_table && /^[[:space:]]*$/ && !printed_non_table { next }
        skip_table && !/^[[:space:]]*$/ { skip_table = 0; printed_non_table = 1 }
        { print }
    ' README.md > README.md.tmp
    mv README.md.tmp README.md

    rm -rf tmp/browser-artifacts

    echo "Browser compatibility matrix updated in README.md from CI and local results"
