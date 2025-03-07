## `sum` command
```
zigmod sum
```

- This will generate a `zig.sum` file with the blake3 hashes of your modules.

`zig.sum` may be checked into source control and there are plans to integrate it into the other commands in the future.

Running it on Zigmod (as of this writing) itself yields:
```
blake3-22472b867734926b202c055892fb0abb03f91556cd88998e2fe77addb003b1dd v/git/github.com/yaml/libyaml/tag-0.2.5
blake3-c9f1cfe1c2bc8f0f7886a29458985491ea15f74c78275c28ce2276007f94d492 v/git/github.com/nektro/zig-ansi/commit-25039ca
blake3-74924ab693ea7730d53839a45805584561fdfc99872f8c307121089070ef6283 v/git/github.com/ziglibs/known-folders/commit-f0f4188
blake3-35adb816bfc0db5e1cc156a2dc61de9b9f15a6e64879cbd0dc962e3c99601850 v/git/github.com/Vexu/zuri/commit-41bcd78
blake3-c876cd16642dee0198d6ce3ba718dcfa199f4f6be4ee239eeb1929b3d52b09a9 v/git/github.com/alexnask/iguanaTLS/commit-1767e48
blake3-c7d7cb3847bdc0fe07dd696504d8e348fce3ae74ca817f2643194ad05f726585 v/git/github.com/nektro/zig-licenses/commit-1a19e4b
```
