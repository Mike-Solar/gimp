/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995 Spencer Kimball and Peter Mattis
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include "gimptransformoptions.h"


#define GIMP_TYPE_MEASURE_OPTIONS            (gimp_measure_options_get_type ())
#define GIMP_MEASURE_OPTIONS(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GIMP_TYPE_MEASURE_OPTIONS, GimpMeasureOptions))
#define GIMP_MEASURE_OPTIONS_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GIMP_TYPE_MEASURE_OPTIONS, GimpMeasureOptionsClass))
#define GIMP_IS_MEASURE_OPTIONS(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GIMP_TYPE_MEASURE_OPTIONS))
#define GIMP_IS_MEASURE_OPTIONS_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GIMP_TYPE_MEASURE_OPTIONS))
#define GIMP_MEASURE_OPTIONS_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GIMP_TYPE_MEASURE_OPTIONS, GimpMeasureOptionsClass))


typedef struct _GimpMeasureOptions      GimpMeasureOptions;
typedef struct _GimpMeasureOptionsClass GimpMeasureOptionsClass;

struct _GimpMeasureOptions
{
  GimpTransformOptions    parent_instance;

  GimpCompassOrientation  orientation;
  gboolean                use_info_window;

  /*  options gui  */
  GtkWidget              *straighten_button;
};

struct _GimpMeasureOptionsClass
{
  GimpTransformOptionsClass  parent_class;
};


GType       gimp_measure_options_get_type (void) G_GNUC_CONST;

GtkWidget * gimp_measure_options_gui      (GimpToolOptions *tool_options);
