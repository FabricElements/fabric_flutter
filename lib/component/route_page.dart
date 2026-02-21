FocusScopeNode currentFocus = FocusScope.of(context);
if (currentFocus != null && !currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
  currentFocus.focusedChild?.unfocus();
}