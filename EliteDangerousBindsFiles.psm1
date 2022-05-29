# Definitions for managing Elite: Dangerous customization files.

# General info:
# - Binds file names have this pattern: <base-name>.<major>.<minor>.binds
# - <major>.<minor> is the game version.
# - Contents are XML with root element named Root.
# - The Root.PresetName attribute is the bindings name shown in the game and
#   must be unique (for a given version of the game).
# - Root.MajorVersion and Root.MinorVersion are left out by controller vendors,
#   and get filled in by the game when the profile is used and copied to a file
#   whose name includes the version number parts.
# - Relevant X56 profile files are assumed to match the pattern "Elite_Dangerous*.pr0".
# - VoiceAttack keeps all its data in a single file.

$MyPath = "$(Split-Path $MyInvocation.MyCommand.Path)"
$ED_Bindings = "$env:LOCALAPPDATA\Frontier Developments\Elite Dangerous\Options\Bindings"
$ED_Backups = "$MyPath\EDBackups"
$X56_Profiles = "$env:PUBLIC\Documents\Logitech\X56"
$VA_Data = "$env:APPDATA\VoiceAttack"
$RC_Opts = "/NJH","/NJS", "/NP"
function Backup-EDBindsFiles ()
{
    Set-Location $MyPath
    git status $ED_Backups
    Read-Host -Prompt "Press any key to continue, Ctl-C to terminate"
    RoboCopy "$ED_Bindings" "$ED_Backups" "*.binds" @RC_Opts
    RoboCopy "$X56_Profiles" "$ED_Backups" "Elite_Dangerous*.pr0"  @RC_Opts
    RoboCopy "$VA_Data" "$ED_Backups" "VoiceAttack.dat"  @RC_Opts
    $yn = Read-Host -Prompt "Commit backup changes now? (y/n)"
    if ($yn -eq "y") {
        git add "$ED_Backups\*"
        git commit "$ED_Backups"
        read-host -Prompt "Press any key to continue"
        $yn = Read-Host -Prompt "Push now? (y/n)"
        if ($yn -eq "y") {
            git push
        }
    }
}

function Restore-EDBindsFiles ()
{
    Copy-Item "$ED_Backups\VoiceAttack.dat" -Destination $VA_DATA
    Get-ChildItem $ED_Backups -Filter "Elite_Dangerous*.pr0" | Copy-Item -Destination $X56_Profiles
    Get-ChildItem $ED_Backups -Filter "*.binds" | Copy-Item -Destination $ED_Bindings 
    read-host -Prompt "Press any key to continue."
}

# TODO:
# - Write a Copy-EDBindsFile function that takes care of XML adjustments. Base it on
#   Copy-EDBindsFile below, but handle the game version number correctly.
# - Make versioned backups. To a git repo, perhaps?
# - Selective restore, don't hammer all the things. Or skip restore fn, do it
#   manually when needed?
# - Maybe export VA data to text files?

Export-ModuleMember Backup-EDBindsFiles, Restore-EDBindsFiles

# ---------
# Below is cruft from an incorrect bunny path, kept for reference.
#
# Problems:
# - The comment about changes always going to a Custom binds file is not true,
#   apparently.
# - A named bind file, when changed, seems to get saved with the game version
#   number (major.minor) inserted before the extension.
# - Vendor binds are distributed without the version number in the file name,
#   and with the Root's MajorVersion and MinorVersion attributes missing. 
# - The game may preferentially display binds with a specified game version
#   number, showing a versionless binds file only if there's no versioned
#   variant present.
#
$ED_Personal_Binds_FN = "The Miller X56.binds"
$ED_Personal_Binds = "$ED_Bindings\$ED_Personal_Binds_FN"
$ED_Personal_Binds_Backup = "$(Split-Path $MyInvocation.MyCommand.Path)\Backups\$ED_Personal_Binds_FN"


# Changes made to bindings in ED are always saved to a Custom.X.binds file,
# where X is the game version number, e.g. 3.0
# This function returns the most recently modified file that matches that pattern.
function Get-LatestEDCustomItem ()
{
    return Get-ChildItem $ED_Bindings -Filter "Custom.*.binds" | Sort-Object LastWriteTime | select-object -first 1
}

# Copy a binds file while updating its preset name in the XML content to match
# the file base name. The preset name does not have to match the file name, but
# it's less confusing if it does, so we enforce that convention.
function Copy-EDBindsFile([string]$path, [string]$destination)
{
    $name = Split-Path $destination -LeafBase
    [xml]$xml = Get-Content $destination
    if ($xml.Root.PresetName -eq $name)
    {
        Copy-Item $path -Destination $destination
    }
    else
    {
        $xml.Root.PresetName = $name
        $xml.Save($destination)
    }
}

# Export-ModuleMember -Variable $ED_Bindings,$ED_Personal_Binds,$ED_Personal_Binds_Backup -Function Get-LatestEDCustomItem,Copy-EDBindsFile