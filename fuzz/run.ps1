param(
    [string]$cmd,
    [string]$target = "cjson"
)

$image = "fuzzpipe"

if ($cmd -eq "build") {
    docker build -t $image -f docker/Dockerfile .
}
elseif ($cmd -eq "shell") {
    docker run -it --rm -v ${PWD}:/workspace $image
}
elseif ($cmd -eq "fuzz") {
    docker run -it --rm -v ${PWD}:/workspace $image bash -lc "chmod +x fuzz/fuzz.sh targets/cjson/fetch.sh targets/cjson/build.sh && ./fuzz/fuzz.sh $target"
}
else {
    Write-Host "Usage:"
    Write-Host ".\fuzz\run.ps1 build"
    Write-Host ".\fuzz\run.ps1 shell"
    Write-Host ".\fuzz\run.ps1 fuzz [target]   (default: cjson)"
}