import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets pXs  = EdgeInsets.all(xs);
  static const EdgeInsets pSm  = EdgeInsets.all(sm);
  static const EdgeInsets pMd  = EdgeInsets.all(md);
  static const EdgeInsets pLg  = EdgeInsets.all(lg);
  static const EdgeInsets pXl  = EdgeInsets.all(xl);
  static const EdgeInsets pXxl = EdgeInsets.all(xxl);

  static const EdgeInsets phXs  = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets phSm  = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets phMd  = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets phLg  = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets phXl  = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets pvXs  = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets pvSm  = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets pvMd  = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets pvLg  = EdgeInsets.symmetric(vertical: lg);

  static const SizedBox gapXs  = SizedBox(height: xs);
  static const SizedBox gapSm  = SizedBox(height: sm);
  static const SizedBox gapMd  = SizedBox(height: md);
  static const SizedBox gapLg  = SizedBox(height: lg);
  static const SizedBox gapXl  = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);

  static const SizedBox hXs  = SizedBox(width: xs);
  static const SizedBox hSm  = SizedBox(width: sm);
  static const SizedBox hMd  = SizedBox(width: md);
  static const SizedBox hLg  = SizedBox(width: lg);
  static const SizedBox hXl  = SizedBox(width: xl);
}
