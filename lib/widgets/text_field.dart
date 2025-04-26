import 'package:flutter/material.dart';

class DoTextField extends TextFormField {
  DoTextField({
    super.key, //
    super.onChanged,
    super.initialValue,
  }) : super(
         onTapOutside: (event) {
           FocusManager.instance.primaryFocus?.unfocus();
         },
       );
}
