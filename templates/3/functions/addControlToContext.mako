% if not 'addControlToContext' in vars:

NK.functions = NK.functions || {};

/**
 *  used by controls templates to place controls in the correct context
 *
 */
NK.functions.addControlToContext = function (control, context) {
  // utility method to add control to map or panel

  if (context.addControl) {
    // context is a map
    context.addControl(control);
  } else if (context.addControls) {
    // context is a panel
    context.addControls([control]);
  }
};

<% vars['addControlToContext']=True %>
% endif