#include <torch/extension.h>

#include "raymarching.h"

PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
  // utils
  m.def("flatten_rays", &flatten_rays, "flatten_rays (SDAA)");
  m.def("packbits", &packbits, "packbits (SDAA)");
  m.def("packbits_triplane", &packbits_triplane, "packbits_triplane (SDAA)");
  m.def("near_far_from_aabb", &near_far_from_aabb, "near_far_from_aabb (SDAA)");
  m.def("sph_from_ray", &sph_from_ray, "sph_from_ray (SDAA)");
  m.def("morton3D", &morton3D, "morton3D (SDAA)");
  m.def("morton3D_invert", &morton3D_invert, "morton3D_invert (SDAA)");
  m.def("morton2D", &morton2D, "morton2D (SDAA)");
  m.def("morton2D_invert", &morton2D_invert, "morton2D_invert (SDAA)");
  // train
  m.def("march_rays_train", &march_rays_train, "march_rays_train (SDAA)");
  m.def("march_rays_triplane_train", &march_rays_triplane_train,
        "march_rays_triplane_train (SDAA)");
  m.def("composite_rays_train_forward", &composite_rays_train_forward,
        "composite_rays_train_forward (SDAA)");
  m.def("composite_rays_train_neus_forward", &composite_rays_train_neus_forward,
        "composite_rays_train_neus_forward (SDAA)");
  m.def("composite_rays_train_hybrid_forward",
        &composite_rays_train_hybrid_forward,
        "composite_rays_train_hybrid_forward (SDAA)");
  m.def("composite_rays_train_backward", &composite_rays_train_backward,
        "composite_rays_train_backward (SDAA)");
  m.def("composite_rays_train_neus_backward",
        &composite_rays_train_neus_backward,
        "composite_rays_train_neus_backward (SDAA)");
  m.def("composite_rays_train_hybrid_backward",
        &composite_rays_train_hybrid_backward,
        "composite_rays_train_hybrid_backward (SDAA)");
  // infer
  m.def("march_rays", &march_rays, "march rays (SDAA)");
  m.def("composite_rays", &composite_rays, "composite rays (SDAA)");
}
