#!/usr/bin/env bash

[ -z "${verbose:-}" ] && verbose=false
__korebuild_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$__korebuild_dir/scripts/common.sh"

# functions
default_tools_source='https://aspnetcore.blob.core.windows.net/buildtools'

set_korebuildsettings() {
    tools_source=$1
    dot_net_home=$2
    repo_path=$3
    local config_file="${4:-}" # optional. Not used yet.
    local ci="${5:-}"

    [ -z "${dot_net_home:-}" ] && dot_net_home="$HOME/.dotnet"
    [ -z "${tools_source:-}" ] && tools_source="$default_tools_source"


    if [ "$ci" = true ]; then
        dot_net_home="$repo_path/.dotnet"

        export CI=true
        export DOTNET_CLI_TELEMETRY_OPTOUT=true
        export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
        export NUGET_SHOW_STACK=true
        export NUGET_PACKAGES="$repo_path/.nuget/packages"
        export DOTNET_HOME="$dot_net_home"
        export MSBUILDDEBUGPATH="$repo_path/artifacts/logs"
    fi

    export DOTNET_ROOT="$DOTNET_HOME"

    return 0
}

invoke_korebuild_command(){
    local command="${1:-}"
    shift

    if [ "$command" = "default-build" ]; then
        __install_tools "$tools_source" "$dot_net_home"
        __invoke_repository_build "$repo_path" "$@"
    elif [ "$command" = "msbuild" ]; then
        __invoke_repository_build "$repo_path" "$@"
    elif [ "$command" = "install-tools" ]; then
        __install_tools "$tools_source" "$dot_net_home"
    else
        __ensure_dotnet

        kore_build_console_dll="$__korebuild_dir/tools/KoreBuild.Console.dll"

        __exec dotnet "$kore_build_console_dll" "$command" \
            --tools-source "$tools_source" \
            --dotnet-home "$dot_net_home" \
            --repo-path "$repo_path" \
            "$@"
    fi
}

__ensure_dotnet() {
    if ! __machine_has dotnet; then
        __install_tools "$tools_source" "$dot_net_home"
    fi
}

__invoke_repository_build() {
    local repo_path=$1
    shift
    verbose_flag=''
    [ "$verbose" = true ] && verbose_flag='--verbose'

    # Call "sync" between "chmod" and execution to prevent "text file busy" error in Docker (aufs)
    chmod +x "$__korebuild_dir/scripts/invoke-repository-build.sh"; sync
    "$__korebuild_dir/scripts/invoke-repository-build.sh" "$repo_path" $verbose_flag "$@"
    return $?
}

__install_tools() {
    local tools_source=$1
    local install_dir=$2
    local tools_home="$install_dir/buildtools"
    local netfx_version='4.6.1'

    verbose_flag=''
    [ "$verbose" = true ] && verbose_flag='--verbose'

    # Instructs MSBuild where to find .NET Framework reference assemblies
    export ReferenceAssemblyRoot="$tools_home/netfx/$netfx_version"

    # Call "sync" between "chmod" and execution to prevent "text file busy" error in Docker (aufs)
    chmod +x "$__korebuild_dir/scripts/get-netfx.sh"; sync
    # we don't include netfx in the BuildTools artifacts currently, it ends up on the blob store through other means, so we'll only look for it in the default_tools_source
    "$__korebuild_dir/scripts/get-netfx.sh" $verbose_flag $netfx_version "$default_tools_source" "$ReferenceAssemblyRoot" \
        || return 1

    # Call "sync" between "chmod" and execution to prevent "text file busy" error in Docker (aufs)
    chmod +x "$__korebuild_dir/scripts/get-dotnet.sh"; sync
    "$__korebuild_dir/scripts/get-dotnet.sh" $verbose_flag "$install_dir" \
        || return 1

    # Set environment variables
    export PATH="$install_dir:$PATH"
}

__show_version_info() {
    MAGENTA="\033[0;95m"
    RESET="\033[0m"

    __korebuild_version="$(__get_korebuild_version)"
    if [[ "$__korebuild_version" != '' ]]; then
        echo -e "${MAGENTA}Using KoreBuild ${__korebuild_version}${RESET}"
    fi
}

# Try to show version on console, but don't fail if this is broken
__show_version_info || true

if [ "$(uname)" = "Darwin" ]; then
    __ensure_macos_version
    # increase file descriptor limit
    ulimit -n 5000
fi

# Set required environment variables

# This disables automatic rollforward to /usr/local/dotnet and other global locations.
# We want to ensure are tests are running against the exact runtime specified by the project.
export DOTNET_MULTILEVEL_LOOKUP=0
