param(
    [string]$cmd,
    [string]$target = "cjson",
    [int]$seconds = 0
)

$image = "fuzzpipe"

if ($cmd -eq "build") {
    docker build -t $image -f docker/Dockerfile .
}
elseif ($cmd -eq "shell") {
    docker run -it --rm -v ${PWD}:/workspace $image
}
elseif ($cmd -eq "fuzz") {
    # seconds=0 means run until Ctrl+C
    $envCmd = ""
    if ($seconds -gt 0) { $envCmd = "MAX_TOTAL_TIME=$seconds " }

    docker run -it --rm `
      -e DOCKER_IMAGE_TAG="$image:latest" `
      -v ${PWD}:/workspace `
      $image bash -lc "chmod +x fuzz/fuzz.sh targets/cjson/fetch.sh targets/cjson/build.sh && ${envCmd}./fuzz/fuzz.sh $target"
}

elseif ($cmd -eq "repro") {
    if (-not $target) { $target = "cjson" }
    if (-not $args[0]) {
        Write-Host "Usage: .\fuzz\run.ps1 repro <target> <crash_path>"
        exit 1
    }
    $crashPath = $args[0]

    docker run -it --rm `
      -e DOCKER_IMAGE_TAG="$image:latest" `
      -v ${PWD}:/workspace `
      $image bash -lc "chmod +x triage/repro.sh && ./triage/repro.sh $target /workspace/$crashPath"
}

else {
    Write-Host "Usage:"
    Write-Host ".\fuzz\run.ps1 build"
    Write-Host ".\fuzz\run.ps1 shell"
    Write-Host ".\fuzz\run.ps1 fuzz [target] [seconds]"
    Write-Host "  example: .\fuzz\run.ps1 fuzz cjson 30"
}