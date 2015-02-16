<%inherit file="/3/controls/controlcontext.mako" />
var buttons = {};
buttons.on = document.createElement('button');
buttons.on.innerHTML = "vis verkt&oslash;y";
buttons.on.setAttribute('class', 'collapse-toolbar-toggle on');
buttons.off = document.createElement('button');
buttons.off.innerHTML = "skjul verkt&oslash;y";
buttons.off.setAttribute('class', 'collapse-toolbar-toggle off');

(function () {
	var collapseToolbar,
		showCollapsedToolbar;

	collapseToolbar = function (evt) {
		var element = this;
                while (!$(element).hasClass('toolbar')) {
                  element = element.parentNode;
                }
		$(element).addClass('collapsed');
		return false;
	};

	showCollapsedToolbar = function (evt) {
		var element = this;
                while (!$(element).hasClass('toolbar')) {
                  element = element.parentNode;
                }
		$(element).removeClass('collapsed');
		return false;
	};

	buttons.off.addEventListener('click', collapseToolbar, false);
	buttons.on.addEventListener('click', showCollapsedToolbar, false);
}());
container.appendChild(buttons.off);
container.appendChild(buttons.on);