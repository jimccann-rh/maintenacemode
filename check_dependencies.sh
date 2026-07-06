#!/bin/bash
# Check and install required Python dependencies for VMware modules

set -e

echo "=========================================="
echo "VMware Ansible Dependencies Check"
echo "=========================================="
echo ""

# Find Python interpreter
if [ -n "$1" ]; then
    PYTHON="$1"
else
    # Try to find Python 3
    for py in python3.11 python3.12 python3.10 python3 python; do
        if command -v $py &> /dev/null; then
            PYTHON=$py
            break
        fi
    done
fi

if [ -z "$PYTHON" ]; then
    echo "ERROR: No Python interpreter found!"
    exit 1
fi

PYTHON_PATH=$(which $PYTHON)
PYTHON_VERSION=$($PYTHON --version 2>&1)

echo "Python interpreter: $PYTHON_PATH"
echo "Python version: $PYTHON_VERSION"
echo ""

# Check required libraries
echo "Checking required Python libraries..."
echo ""

MISSING=()

check_module() {
    local module=$1
    local display_name=${2:-$1}

    if $PYTHON -c "import $module" 2>/dev/null; then
        local version=$($PYTHON -c "import $module; print(getattr($module, '__version__', 'unknown'))" 2>/dev/null)
        echo "✓ $display_name: installed (version: $version)"
        return 0
    else
        echo "✗ $display_name: NOT installed"
        MISSING+=("$display_name")
        return 1
    fi
}

check_module "requests" "requests"
check_module "pyVmomi" "pyVmomi"
check_module "pyvim" "pyvim"

echo ""

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "=========================================="
    echo "✓ All dependencies are installed!"
    echo "=========================================="
    echo ""
    echo "You can run the playbook with:"
    echo "  ansible-playbook vmware_maintenance_mode.yml \\"
    echo "    --extra-vars '@vault.yml' \\"
    echo "    --extra-vars \"ansible_python_interpreter=$PYTHON_PATH\" \\"
    echo "    --ask-vault-pass"
    exit 0
else
    echo "=========================================="
    echo "✗ Missing dependencies: ${MISSING[*]}"
    echo "=========================================="
    echo ""
    echo "Install missing dependencies:"
    echo ""
    echo "  $PYTHON -m pip install --user requests pyVmomi pyvim"
    echo ""
    echo "OR use system package manager:"
    echo ""
    echo "  # For RHEL/Fedora/CentOS:"
    echo "  sudo dnf install python3-requests python3-pyvmomi"
    echo ""
    echo "  # For Ubuntu/Debian:"
    echo "  sudo apt install python3-requests python3-pyvmomi"
    echo ""
    echo "After installing, run this script again to verify."
    exit 1
fi
