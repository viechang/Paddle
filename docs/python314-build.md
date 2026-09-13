# Python 3.14 构建说明

本仓库的 `.github/workflows/build-python314-wheels.yml` 使用 CPython 3.14
分别在 Windows x86_64、macOS arm64 和 Linux x86_64 上构建 CPU wheel，并在
构建机上安装后执行最小导入验证。

## 兼容性修复

- C++20 删除了 `std::result_of`。`DDim::apply_visitor` 使用
  `std::invoke_result_t`，避免在 MSVC 的 C++20 头文件中引用已移除的类型。
- CPython 3.14 的 `_PyStackRef` 和解释器帧内部 API 在 Windows 上尚未被
  Paddle SOT 适配。Windows + Python 3.14 构建不编译 `sot/guards.cc` 和
  `sot/cpython_internals/internals_3_14.c`，并通过 `SOT_IS_SUPPORTED=0`
  禁用 SOT 运行路径；普通 Paddle Python API 不受影响。
- MSVC 会将 `TensorOptions(Device)` 同时匹配两个模板构造函数。设备单参数
  构造函数改为非显式，并从可变参数构造函数中排除 `Device` 单参数情况。

## 构建边界

Linux job 在 GitHub 托管的 Ubuntu runner 上生成 `linux_x86_64` wheel。它是
针对该 runner 用户态构建的产物，不宣称 manylinux 兼容性。若要发布到更广泛
的 Linux 环境，应在 manylinux 容器中重新构建并执行 auditwheel 验证。

Windows job 使用 Ninja 和 MSVC x64；macOS job 使用 `macos-14` 的 arm64
runner，wheel 标签为 `macosx_11_0_arm64`。workflow 只构建 CPU 版本，不包含
CUDA、TensorRT 或分布式组件。

## Windows Ninja 并行参数

Windows 使用 Ninja 时，`cmake --build` 必须接收 Ninja 的 `-j` 参数；
`/p:CL_MPCount=...` 是 Visual Studio/MSBuild 参数，传给 Ninja 会被误判为
构建目标并产生 `unknown target '/p:CL_MPCount=...'`。`setup.py` 现在仅在
Visual Studio 生成器下传递 MSBuild 参数，其他生成器使用 `-j`。

构建环境将 CMake 的 `CMP0148` 设为 `OLD`，以兼容当前 Paddle 使用的
`FindPythonInterp`/`FindPythonLibs` 查找逻辑，不改变 Python 3.14 的解释器选择。
