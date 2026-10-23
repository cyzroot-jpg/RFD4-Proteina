import os
from setuptools import setup

_src_path = os.path.dirname(os.path.abspath(__file__))

USE_SDAA = os.environ.get("USE_SDAA", "0") == "1"

if USE_SDAA:
    import torch, torch_sdaa
    from torch_sdaa.utils.cpp_extension import TecoExtension, BuildExtension, CleanExtension
    print("***  SDAA  ***")
    print(torch.utils.cpp_extension.include_paths())
    ext_name = '_raymarching_mob'
    setup(
        name="raymarching_mob",  # Python模块名称，使用时import的名字
        ext_modules=[
            TecoExtension(  # 添加一个或多个TecoExtension
                name=ext_name,  # C++扩展模块名称，保持相同即可
                # 指定要编译的文件
                sources=[
                    os.path.join(_src_path, "src_sdaa", f)
                    for f in [
                        "raymarching.scpp",
                        "bindings.cpp",
                    ]
                ],
                include_dirs=torch.utils.cpp_extension.include_paths(),
            )
        ],
        install_requires=["torch", "torch_sdaa"],
        cmdclass={"build_ext": BuildExtension, "clean": CleanExtension},
    )

else:
    print("***  CUDA  ***")
    from torch.utils.cpp_extension import BuildExtension, CUDAExtension

    nvcc_flags = [
        '-O3', '-std=c++17',
        '-U__CUDA_NO_HALF_OPERATORS__', '-U__CUDA_NO_HALF_CONVERSIONS__', '-U__CUDA_NO_HALF2_OPERATORS__',
    ]

    if os.name == "posix":
        c_flags = ['-O3', '-std=c++17']
    elif os.name == "nt":
        c_flags = ['/O2', '/std:c++17']

        # find cl.exe
        def find_cl_path():
            import glob
            for edition in ["Enterprise", "Professional", "BuildTools", "Community"]:
                paths = sorted(glob.glob(r"C:\\Program Files (x86)\\Microsoft Visual Studio\\*\\%s\\VC\\Tools\\MSVC\\*\\bin\\Hostx64\\x64" % edition), reverse=True)
                if paths:
                    return paths[0]

        # If cl.exe is not on path, try to find it.
        if os.system("where cl.exe >nul 2>nul") != 0:
            cl_path = find_cl_path()
            if cl_path is None:
                raise RuntimeError("Could not locate a supported Microsoft Visual C++ installation")
            os.environ["PATH"] += ";" + cl_path

    '''
    Usage:

    python setup.py build_ext --inplace # build extensions locally, do not install (only can be used from the parent directory)

    python setup.py install # build extensions and install (copy) to PATH.
    pip install . # ditto but better (e.g., dependency & metadata handling)

    python setup.py develop # build extensions and install (symbolic) to PATH.
    pip install -e . # ditto but better (e.g., dependency & metadata handling)

    '''
    setup(
        name='raymarching_mob', # package name, import this to use python API
        ext_modules=[
            CUDAExtension(
                name='_raymarching_mob', # extension name, import this to use CUDA API
                sources=[os.path.join(_src_path, 'src', f) for f in [
                    'raymarching.cu',
                    'bindings.cpp',
                ]],
                extra_compile_args={
                    'cxx': c_flags,
                    'nvcc': nvcc_flags,
                }
            ),
        ],
        cmdclass={
            'build_ext': BuildExtension,
        }
    )



