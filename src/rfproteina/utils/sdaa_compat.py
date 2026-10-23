"""Runtime compatibility shims for the Teco SDAA (TecoPyTorch) platform.

Importing and calling :func:`activate_accelerator_compat` is a no-op on CPU/CUDA
hosts.  On an SDAA host it:

* registers ``torch_sdaa`` and enables TecoPyTorch's automatic CUDA -> SDAA
  migration, so the unchanged CUDA-oriented model code (``torch.cuda.*``,
  ``device="cuda"``, ...) runs on SDAA;
* restores the ``biotite==1.6.0`` module layout that AtomWorks imports (the
  LoongArch biotite builds are API-compatible but report a newer/dev version and
  moved ``connect_via_residue_names`` out of ``biotite.structure.bonds``).

The shims are deliberately narrow: they only run when an SDAA device is present
and only touch the exact symbols that are missing.
"""

from __future__ import annotations

import logging
import os

import torch

logger = logging.getLogger(__name__)

_SDAA_ACTIVE = False


def sdaa_is_active() -> bool:
    """Return True when the CUDA -> SDAA migration backend is active."""
    return _SDAA_ACTIVE


def _activate_sdaa_backend() -> bool:
    """Enable ``torch_sdaa`` device support and the CUDA -> SDAA auto migration."""
    global _SDAA_ACTIVE

    # Explicit opt-out for CPU runs on an SDAA host (hardware.accelerator=cpu).
    if os.environ.get("RFPROTEINA_DISABLE_SDAA", "").strip().lower() in {"1", "true", "yes", "on"}:
        return False

    # A real CUDA build already reports a CUDA device; never hijack it.
    if torch.cuda.is_available():
        return False

    try:
        import torch_sdaa  # noqa: F401
    except ImportError:
        return False

    try:
        if not torch.sdaa.is_available():
            return False
    except AttributeError:
        return False

    # TecoPyTorch's auto-migration maps torch.cuda.* and device="cuda" onto SDAA.
    from torch_sdaa.utils import cuda_migrate  # noqa: F401

    if not torch.cuda.is_available():  # pragma: no cover - defensive
        return False

    # ``torch._dynamo`` (imported by torchvision/torchmetrics, even when we never
    # compile) reads ``torch.cuda._CudaDeviceProperties``. After the migration
    # ``torch.cuda`` resolves to ``torch_sdaa.backend``, which only exposes the
    # SDAA-named class.
    try:
        import torch_sdaa.backend as _sdaa_backend

        if not hasattr(_sdaa_backend, "_CudaDeviceProperties"):
            _sdaa_backend._CudaDeviceProperties = _sdaa_backend._SDAADeviceProperties
        # torch._dynamo.device_interface.CudaInterface resolves a handful of
        # private stream helpers at import time. SDAA has no CUDA streams, and
        # we never compile on this backend, so provide inert equivalents.
        if not hasattr(_sdaa_backend, "_set_stream_by_id"):
            _sdaa_backend._set_stream_by_id = lambda *args, **kwargs: None
        if not hasattr(_sdaa_backend, "_exchange_device"):
            _sdaa_backend._exchange_device = lambda device: device
        if not hasattr(_sdaa_backend, "_maybe_exchange_device"):
            _sdaa_backend._maybe_exchange_device = lambda device: device

        # TecoPyTorch exposes ``torch.Event`` / ``torch.Stream`` as deprecated
        # factory functions. torch._dynamo subclasses them, so expose the real
        # SDAA classes instead.
        if not isinstance(torch.Event, type):
            torch.Event = _sdaa_backend.Event
        if not isinstance(torch.Stream, type):
            torch.Stream = _sdaa_backend.Stream

        # Libraries such as transformers annotate ``torch.cuda.CUDAGraph`` at
        # import time. SDAA exposes the same concept under its own name.
        if not hasattr(_sdaa_backend, "CUDAGraph"):
            _sdaa_backend.CUDAGraph = _sdaa_backend.SDAAGraph

        # Lightning's CUDA accelerator probes the compute capability to decide
        # whether tensor cores are available. SDAA raises NotImplementedError;
        # report a modern capability so Lightning takes the tensor-core branch.
        _sdaa_backend.get_device_capability = lambda device=None: (8, 0)
    except (ImportError, AttributeError):
        pass

    _SDAA_ACTIVE = True
    logger.info("TecoPyTorch SDAA detected: CUDA -> SDAA automatic migration is active.")
    return True


def _patch_biotite_layout() -> None:
    """Bridge the biotite 1.6 / 1.7 module-layout gap used by AtomWorks."""
    try:
        import biotite
        import biotite.structure.bonds as bonds
    except ImportError:
        return

    # biotite >= 1.7 moved the residue-template bond connector to
    # ``biotite.structure.connect``; AtomWorks (pinned to 1.6.0) imports it from
    # ``biotite.structure.bonds``.
    if not hasattr(bonds, "connect_via_residue_names"):
        try:
            from biotite.structure.connect import connect_via_residue_names

            bonds.connect_via_residue_names = connect_via_residue_names
            logger.info("biotite compatibility: exposed connect_via_residue_names on biotite.structure.bonds.")
        except ImportError:
            pass

    # AtomWorks reads ``BondList._bonds`` (a 1.6 private attribute). In 1.7 the
    # bond table is only exposed through the public ``as_array()``.
    try:
        from biotite.structure import BondList

        if not hasattr(BondList, "_bonds"):
            BondList._bonds = property(lambda self: self.as_array())
    except (ImportError, AttributeError):
        pass

    # AtomWorks hard-enforces an exact biotite version string. The available
    # LoongArch builds are API-compatible with 1.6.0 but report 1.7.x / 0.1.dev.
    # Present the pinned version only; the symbol above is what actually differs.
    try:
        version = str(biotite.__version__)
        major_minor = tuple(int(part) for part in version.split(".")[:2])
        if major_minor >= (1, 6) and version != "1.6.0":
            biotite.__version__ = "1.6.0"
            logger.info("biotite compatibility: reporting API-compatible build %s as 1.6.0.", version)
    except (ValueError, TypeError):
        pass


def _patch_rdkit_layout() -> None:
    """Provide ``rdkit.Chem.rdDetermineBonds`` when a build omits the module.

    The available LoongArch rdkit wheel ships every module AtomWorks imports
    except ``rdDetermineBonds``. AtomWorks imports it unconditionally but uses it
    only for coordinate-based bond perception (``infer_bonds=True``), which the
    annotated-CIF inference path does not need. Install a stub that fails loudly
    only if that path is actually exercised.
    """
    import sys
    import types

    import rdkit.Chem as _rdchem

    try:
        from rdkit.Chem import rdDetermineBonds  # noqa: F401
    except ImportError:
        module = types.ModuleType("rdkit.Chem.rdDetermineBonds")

        def DetermineBonds(*args, **kwargs):  # noqa: N802 - mirror the rdkit API
            raise NotImplementedError(
                "rdDetermineBonds is missing from this rdkit build; coordinate-based bond "
                "perception (infer_bonds=True) is unavailable. Supply explicit bonds in the input."
            )

        module.DetermineBonds = DetermineBonds
        sys.modules.setdefault("rdkit.Chem.rdDetermineBonds", module)
        _rdchem.rdDetermineBonds = module
        logger.info("rdkit compatibility: installed a stub rdDetermineBonds (infer_bonds unavailable).")

    try:
        from rdkit.Chem import rdEHTTools  # noqa: F401
    except ImportError:
        module = types.ModuleType("rdkit.Chem.rdEHTTools")

        def RunMol(*args, **kwargs):  # noqa: N802 - mirror the rdkit API
            raise NotImplementedError(
                "rdEHTTools is missing from this rdkit build; Hueckel-based bond perception is unavailable."
            )

        module.RunMol = RunMol
        sys.modules.setdefault("rdkit.Chem.rdEHTTools", module)
        _rdchem.rdEHTTools = module
        logger.info("rdkit compatibility: installed a stub rdEHTTools (Hueckel perception unavailable).")

    # The LoongArch rdkit wheel is built without InChI, but AtomWorks imports
    # MolFromInchi at module scope. Provide raising stubs for the InChI helpers.
    try:
        import rdkit.Chem.inchi as _inchi

        for _name in ("MolFromInchi", "MolToInchi", "MolToInchiKey", "InchiToInchiKey"):

            def _unavailable(*args, __name=_name, **kwargs):
                raise NotImplementedError(f"rdkit.Chem.inchi.{__name} is unavailable in this rdkit build (no InChI).")

            if not hasattr(_inchi, _name):
                setattr(_inchi, _name, _unavailable)
    except ImportError:
        pass


def _patch_pyarrow_layout() -> None:
    """Allow ``import pyarrow.parquet`` when a build ships without the Parquet extension.

    The LoongArch pyarrow wheel omits ``_parquet``. AtomWorks imports
    ``pyarrow.parquet`` at module scope for its optional dataset cache; the
    inference path never reads Parquet, so a raising stub keeps the import graph
    intact while making any accidental use explicit.
    """
    try:
        import pyarrow.parquet  # noqa: F401
        return
    except ImportError:
        pass

    import sys
    import types

    import pyarrow

    module = types.ModuleType("pyarrow.parquet")

    def _unavailable(*args, **kwargs):
        raise NotImplementedError("pyarrow.parquet is unavailable in this pyarrow build (missing _parquet).")

    for name in (
        "write_table",
        "read_table",
        "read_schema",
        "read_metadata",
        "write_metadata",
        "ParquetFile",
        "ParquetWriter",
    ):
        setattr(module, name, _unavailable)
    sys.modules.setdefault("pyarrow.parquet", module)
    pyarrow.parquet = module
    logger.info("pyarrow compatibility: installed a stub pyarrow.parquet (Parquet I/O unavailable).")


def activate_accelerator_compat() -> None:
    """Enable SDAA support (no-op on CPU/CUDA) and the biotite layout bridge.

    Call this once, as early as possible after importing :mod:`torch`, before
    AtomWorks / Lightning read the device configuration.
    """
    _activate_sdaa_backend()
    _patch_biotite_layout()
    _patch_rdkit_layout()
    _patch_pyarrow_layout()