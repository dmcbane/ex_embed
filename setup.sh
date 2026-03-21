#!/bin/bash

# ExEmbed Setup Script
# Prepares the development environment for building and testing

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HAS_ERRORS=0

echo "========================================="
echo "ExEmbed Setup"
echo "========================================="
echo ""
echo "Checking prerequisites..."
echo ""

# Check Elixir
if ! command -v elixir &> /dev/null; then
    echo -e "${RED}❌ Elixir is not installed.${NC}"
    echo "   Elixir 1.16+ required."
    echo "   https://elixir-lang.org/install.html"
    HAS_ERRORS=1
else
    ELIXIR_VERSION=$(elixir --version | grep Elixir)
    echo -e "${GREEN}✅ $ELIXIR_VERSION${NC}"
fi

# Check Erlang/OTP
if ! command -v erl &> /dev/null; then
    echo -e "${RED}❌ Erlang/OTP is not installed.${NC}"
    HAS_ERRORS=1
else
    OTP_VERSION=$(erl -noshell -eval 'io:format("OTP ~s", [erlang:system_info(otp_release)]), halt().')
    echo -e "${GREEN}✅ $OTP_VERSION${NC}"
fi

# Check Rust (required for ortex NIF compilation)
if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}⚠️  Rust toolchain not found. Will install via rustup.${NC}"
    NEED_RUST=1
else
    RUST_VERSION=$(rustc --version)
    echo -e "${GREEN}✅ $RUST_VERSION${NC}"
    NEED_RUST=0
fi

echo ""
echo "========================================="

if [ $HAS_ERRORS -eq 1 ]; then
    echo -e "${RED}❌ Setup cannot continue due to missing requirements.${NC}"
    exit 1
fi

echo ""

# Install Rust if needed (required for ortex ONNX Runtime NIF)
if [ "$NEED_RUST" = "1" ]; then
    echo "Step 1: Installing Rust toolchain (required for ortex)..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        . "$HOME/.cargo/env"
        echo -e "${GREEN}✅ Rust installed: $(rustc --version)${NC}"
    else
        echo -e "${RED}❌ Failed to install Rust${NC}"
        exit 1
    fi
else
    echo "Step 1: Rust toolchain already installed"
    echo -e "${GREEN}✅ Skipped${NC}"
fi

# Source cargo env in case it was just installed
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

echo ""
echo "Step 2: Installing Elixir dependencies..."
mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get
echo -e "${GREEN}✅ Dependencies installed${NC}"

echo ""
echo "Step 3: Compiling (includes ortex NIF — this may take a few minutes)..."
if mix compile; then
    echo -e "${GREEN}✅ Compilation complete${NC}"
else
    echo -e "${RED}❌ Compilation failed${NC}"
    exit 1
fi

echo ""
echo "Step 4: Downloading default embedding model..."
echo "   Model: BAAI/bge-small-en-v1.5 (67MB quantized ONNX)"
if mix ex_embed.download bge-small-en-v1.5; then
    echo -e "${GREEN}✅ Model downloaded${NC}"
else
    echo -e "${YELLOW}⚠️  Model download failed (network issue?)${NC}"
    echo "   Tests tagged :requires_model will be excluded."
    echo "   Retry later: mix ex_embed.download bge-small-en-v1.5"
fi

echo ""
echo "Step 5: Running tests..."
if mix test; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Useful commands:"
echo ""
echo "  mix test                              # Run all tests"
echo "  mix test --include requires_network   # Include network tests"
echo "  mix ex_embed.list                     # List available models"
echo "  mix ex_embed.download <model>         # Download a model"
echo ""
echo "Quick start in IEx:"
echo ""
echo "  iex -S mix"
echo "  {:ok, tensor} = ExEmbed.embed(\"Hello, world!\")"
echo "  Nx.shape(tensor)  # => {1, 384}"
echo ""
echo "========================================="
