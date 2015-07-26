#include "clone.h"


/**
 * @brief Given a pointer to a Material on the host and a dev_material on the
 *        GPU, copy all of the properties from the Material object on the host
 *        struct to the GPU.
 * @details This routine is called by the GPUSolver::initializeMaterials()
 *          private class method and is not intended to be called directly.
 * @param material_h pointer to a Material on the host
 * @param material_d pointer to a dev_material on the GPU
 */
void clone_material(Material* material_h, dev_material* material_d) {

  /* Copy over the Material's ID */
  int id = material_h->getId();
  int num_groups = material_h->getNumEnergyGroups();

  cudaMemcpy((void*)&material_d->_id, (void*)&id, sizeof(int),
             cudaMemcpyHostToDevice);

  /* Allocate memory on the device for each dev_material data array */
  double* sigma_t;
  double* sigma_a;
  double* sigma_s;
  double* sigma_f;
  double* nu_sigma_f;
  double* chi;

  /* Allocate memory on device for dev_material data arrays */
  cudaMalloc((void**)&sigma_t, num_groups * sizeof(double));
  cudaMalloc((void**)&sigma_a, num_groups * sizeof(double));
  cudaMalloc((void**)&sigma_s, num_groups * num_groups * sizeof(double));
  cudaMalloc((void**)&sigma_f, num_groups * sizeof(double));
  cudaMalloc((void**)&nu_sigma_f, num_groups * sizeof(double));
  cudaMalloc((void**)&chi, num_groups * sizeof(double));

  /* Copy Material data from host to arrays on the device */
  cudaMemcpy((void*)sigma_t, (void*)material_h->getSigmaT(),
             num_groups * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)sigma_a, (void*)material_h->getSigmaA(),
             num_groups * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)sigma_s, (void*)material_h->getSigmaS(),
             num_groups * num_groups * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)sigma_f, (void*)material_h->getSigmaF(),
             num_groups * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)nu_sigma_f, (void*)material_h->getNuSigmaF(),
             num_groups * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)chi, (void*)material_h->getChi(),
             num_groups * sizeof(double), cudaMemcpyHostToDevice);

  /* Copy Material data pointers to dev_material on GPU */
  cudaMemcpy((void*)&material_d->_sigma_t, (void*)&sigma_t, sizeof(double*),
             cudaMemcpyHostToDevice);
  cudaMemcpy((void*)&material_d->_sigma_a, (void*)&sigma_a, sizeof(double*),
             cudaMemcpyHostToDevice);
  cudaMemcpy((void*)&material_d->_sigma_s, (void*)&sigma_s, sizeof(double*),
             cudaMemcpyHostToDevice);
  cudaMemcpy((void*)&material_d->_sigma_f, (void*)&sigma_f, sizeof(double*),
             cudaMemcpyHostToDevice);
  cudaMemcpy((void*)&material_d->_nu_sigma_f, (void*)&nu_sigma_f,
             sizeof(double*), cudaMemcpyHostToDevice);
  cudaMemcpy((void*)&material_d->_chi, (void*)&chi, sizeof(double*),
             cudaMemcpyHostToDevice);

  return;
}


/**
 * @brief Given a pointer to a Track on the host, a dev_track on
 *        the GPU, and the map of material IDs to indices in the 
 *        _materials array, copy all of the class attributes and 
 *        segments from the Track object on the host to the GPU.  
 * @details This routine is called by the GPUSolver::initializeTracks()
 *          private class method and is not intended to be called
 *          directly.  
 * @param track_h pointer to a Track on the host
 * @param track_d pointer to a dev_track on the GPU
 * @param material_IDs_to_indices map of material IDs to indices
 *        in the _materials array.
 */
void clone_track(Track* track_h, dev_track* track_d, 
     		 std::map<int, int> &material_IDs_to_indices) {

  dev_segment* dev_segments;
  dev_segment* host_segments = new dev_segment[track_h->getNumSegments()];
  dev_track new_track;

  new_track._uid = track_h->getUid();
  new_track._num_segments = track_h->getNumSegments();
  new_track._azim_angle_index = track_h->getAzimAngleIndex();
  new_track._refl_in = track_h->isReflIn();
  new_track._refl_out = track_h->isReflOut();

  if (track_h->getBCIn() == REFLECTIVE || track_h->getBCIn() == PERIODIC)
    new_track._bc_in = 1;
  else
    new_track._bc_in = 0;

  if (track_h->getBCOut() == REFLECTIVE || track_h->getBCOut() == PERIODIC)
    new_track._bc_out = 1;
  else
    new_track._bc_out = 0;
    
  cudaMalloc((void**)&dev_segments,
             track_h->getNumSegments() * sizeof(dev_segment));
  new_track._segments = dev_segments;

  for (int s=0; s < track_h->getNumSegments(); s++) {
    segment* curr = track_h->getSegment(s);
    host_segments[s]._length = curr->_length;
    host_segments[s]._region_uid = curr->_region_id;
    host_segments[s]._material_index = 
      material_IDs_to_indices[curr->_material->getId()];
  }

  cudaMemcpy((void*)dev_segments, (void*)host_segments,
             track_h->getNumSegments() * sizeof(dev_segment),
             cudaMemcpyHostToDevice);
  cudaMemcpy((void*)track_d, (void*)&new_track, sizeof(dev_track),
             cudaMemcpyHostToDevice);

  delete [] host_segments;

  return;
}