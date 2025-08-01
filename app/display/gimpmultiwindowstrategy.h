/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995 Spencer Kimball and Peter Mattis
 *
 * gimpmultiwindowstrategy.h
 * Copyright (C) 2011 Martin Nordholts <martinn@src.gnome.org>
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

#include "core/gimpobject.h"


#define GIMP_TYPE_MULTI_WINDOW_STRATEGY            (gimp_multi_window_strategy_get_type ())
#define GIMP_MULTI_WINDOW_STRATEGY(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GIMP_TYPE_MULTI_WINDOW_STRATEGY, GimpMultiWindowStrategy))
#define GIMP_MULTI_WINDOW_STRATEGY_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GIMP_TYPE_MULTI_WINDOW_STRATEGY, GimpMultiWindowStrategyClass))
#define GIMP_IS_MULTI_WINDOW_STRATEGY(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GIMP_TYPE_MULTI_WINDOW_STRATEGY))
#define GIMP_IS_MULTI_WINDOW_STRATEGY_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GIMP_TYPE_MULTI_WINDOW_STRATEGY))
#define GIMP_MULTI_WINDOW_STRATEGY_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GIMP_TYPE_MULTI_WINDOW_STRATEGY, GimpMultiWindowStrategyClass))


typedef struct _GimpMultiWindowStrategyClass GimpMultiWindowStrategyClass;

struct _GimpMultiWindowStrategy
{
  GimpObject  parent_instance;
};

struct _GimpMultiWindowStrategyClass
{
  GimpObjectClass  parent_class;
};


GType        gimp_multi_window_strategy_get_type          (void) G_GNUC_CONST;

GimpObject * gimp_multi_window_strategy_get_singleton     (void);
