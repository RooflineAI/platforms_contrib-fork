load("@with_cfg.bzl", "with_cfg")

linux_x86_64_filegroup, _linux_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:linux_x86_64_musl")])
        .build()
)

macos_x86_64_filegroup, _macos_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:macos_x86_64")])
        .build()
)

windows_x86_64_filegroup, _windows_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:windows_x86_64")])
        .build()
)
