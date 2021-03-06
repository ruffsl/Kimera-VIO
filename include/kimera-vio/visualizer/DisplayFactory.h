/* ----------------------------------------------------------------------------
 * Copyright 2017, Massachusetts Institute of Technology,
 * Cambridge, MA 02139
 * All Rights Reserved
 * Authors: Luca Carlone, et al. (see THANKS for the full author list)
 * See LICENSE for the license information
 * -------------------------------------------------------------------------- */

/**
 * @file   DisplayFactory.h
 * @brief  Display factory
 * @author Antoni Rosinol
 */

#pragma once

#include <glog/logging.h>

#include "kimera-vio/utils/Macros.h"
#include "kimera-vio/visualizer/Display.h"

namespace VIO {

class DisplayFactory {
 public:
  KIMERA_POINTER_TYPEDEFS(DisplayFactory);
  KIMERA_DELETE_COPY_CONSTRUCTORS(DisplayFactory);

  DisplayFactory() = default;
  virtual ~DisplayFactory() = default;

  static DisplayBase::UniquePtr makeDisplay(
      const DisplayType& display_type,
      const ShutdownPipelineCallback& shutdown_pipeline_cb) {
    switch (display_type) {
      case DisplayType::kOpenCV: {
        return VIO::make_unique<OpenCv3dDisplay>(shutdown_pipeline_cb);
      }
      default: {
        LOG(FATAL) << "Requested display type is not supported.\n"
                   << "Currently supported display types:\n"
                   << "0: OpenCV 3D viz\n 1: Pangolin (not supported yet)\n"
                   << " but requested display: "
                   << static_cast<int>(display_type);
      }
    }
  }
};

}  // namespace VIO
