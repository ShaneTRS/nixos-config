const SteamControllerDevice = require("./src/hid.js");
const theme = require("./theme/base.js");

const dev = new SteamControllerDevice();
// dev.on('tpl_pos_x', s => console.log(s.tpl.pos.x))
// setInterval(_ => document.getElementById('hey').innerHTML = JSON.stringify(dev.state), 10)

const pads_left = document.getElementById("pads_left");
const pads_right = document.getElementById("pads_right");
const pads_lclick = document.getElementById("pads_lclick");
const pads_rclick = document.getElementById("pads_rclick");

// Canva
const lctx = pads_left.getContext("2d");
const rctx = pads_right.getContext("2d");

const buttons = document.getElementById("buttons");
const buttons_a = document.getElementById("buttons_a");
const buttons_b = document.getElementById("buttons_b");
const buttons_x = document.getElementById("buttons_x");
const buttons_y = document.getElementById("buttons_y");

const system = document.getElementById("system");
const system_select = document.getElementById("system_select");
const system_steam = document.getElementById("system_steam");
const system_start = document.getElementById("system_start");

const bumpers = document.getElementById("bumpers");
const bumpers_left = document.getElementById("bumpers_left");
const bumpers_right = document.getElementById("bumpers_right");

const grips = document.getElementById("grips");
const grips_left = document.getElementById("grips_left");
const grips_right = document.getElementById("grips_right");

const triggers = document.getElementById("triggers");
const triggers_left = document.getElementById("triggers_left");
const triggers_right = document.getElementById("triggers_right");

const stick = document.getElementById("stick");
const stick_click = document.getElementById("stick_click");

// Vars
const canvasSize = 200;
const stickCanvasSize = 150;
const maxPointerRadius = 20;
const maxStickRadius = 40;
const previousStackSize = 60;
const lPreviousStack = [];
const rPreviousStack = [];

// Steam controller raw value to canvas coordinate conversions
const rawToCanvasCoord = (x) =>
	Math.floor(((x + (1 << 15)) / (1 << 16)) * (canvasSize - 2 * maxPointerRadius)) + maxPointerRadius;
const rawToStickCoord = (x) =>
	Math.floor(((x + (1 << 15)) / (1 << 16)) * (stickCanvasSize - 2 * maxStickRadius)) + maxStickRadius;
// Transform canva based on theme.js

[pads_left, pads_lclick].forEach((button) => {
	button.style.top = `${theme.pads_left.top}%`;
	button.style.left = `${theme.pads_left.left}%`;
	button.style.width = `${theme.pads_left.size}%`;
	button.style.transform = `rotate(${theme.pads_left.rotate}deg)`;
});

[pads_right, pads_rclick].forEach((button) => {
	button.style.top = `${theme.pads_right.top}%`;
	button.style.right = `${theme.pads_right.right}%`;
	button.style.width = `${theme.pads_right.size}%`;
	button.style.transform = `rotate(${theme.pads_right.rotate}deg)`;
});

stick.style.top = `${theme.stick.top}%`;
stick.style.left = `${theme.stick.left}%`;
stick.style.width = `${theme.stick.size - 8}%`;
stick.style.transform = `rotate(${theme.stick.rotate}deg)`;

stick_click.style.top = `${theme.stick.top + 3}%`;
stick_click.style.left = `${theme.stick.left + 3}%`;
stick_click.style.width = `${theme.stick.size - 8}%`;
stick_click.style.transform = `rotate(${theme.stick.rotate}deg)`;

[buttons, buttons_a, buttons_b, buttons_x, buttons_y].forEach((button) => {
	button.style.top = `${theme.buttons.top}%`;
	button.style.right = `${theme.buttons.right}%`;
	button.style.width = `${theme.buttons.size}%`;
	button.style.transform = `rotate(${theme.buttons.rotate}deg)`;
});

[system, system_select, system_steam, system_start].forEach((button) => {
	button.style.top = `${theme.system.top}%`;
	button.style.right = `${theme.system.right}%`;
	button.style.width = `${theme.system.size}%`;
	button.style.transform = `rotate(${theme.system.rotate}deg)`;
});

[bumpers, bumpers_left, bumpers_right].forEach((button) => {
	button.style.top = `${theme.bumpers.top}%`;
	button.style.right = `${theme.bumpers.right}%`;
	button.style.width = `${theme.bumpers.size}%`;
	button.style.transform = `rotate(${theme.bumpers.rotate}deg)`;
});

[grips, grips_left, grips_right].forEach((button) => {
	button.style.top = `${theme.grips.top}%`;
	button.style.right = `${theme.grips.right}%`;
	button.style.width = `${theme.grips.size}%`;
	button.style.transform = `rotate(${theme.grips.rotate}deg)`;
});

[triggers, triggers_left, triggers_right].forEach((button) => {
	button.style.top = `${theme.triggers.top}%`;
	button.style.right = `${theme.triggers.right}%`;
	button.style.width = `${theme.triggers.size}%`;
	button.style.transform = `rotate(${theme.triggers.rotate}deg)`;
});

/**
 * Main logic to draw on canvas
 */
function refreshCanvas() {
	const lposx = rawToCanvasCoord(dev.state.tpl.pos.x);
	const lposy = rawToCanvasCoord(-dev.state.tpl.pos.y);
	const rposx = rawToCanvasCoord(dev.state.tpr.pos.x);
	const rposy = rawToCanvasCoord(-dev.state.tpr.pos.y);
	const stickx = rawToStickCoord(dev.state.joystick.pos.x);
	const sticky = rawToStickCoord(-dev.state.joystick.pos.y);

	// Clear canvases
	lctx.clearRect(0, 0, canvasSize, canvasSize);
	rctx.clearRect(0, 0, canvasSize, canvasSize);

	// Touchpad touches
	if (dev.state.tpl.touched) {
		while (lPreviousStack.length < previousStackSize) lPreviousStack.push([lposx, lposy]);
	}
	if (dev.state.tpr.touched) {
		while (rPreviousStack.length < previousStackSize) rPreviousStack.push([rposx, rposy]);
	}

	while (lPreviousStack.length > 50) lPreviousStack.shift();
	while (rPreviousStack.length > 50) rPreviousStack.shift();

	lPreviousStack.shift();
	rPreviousStack.shift();
	for (let i = 0; i < lPreviousStack.length; i++) {
		let [x, y] = lPreviousStack[i];
		drawPointer(lctx, x, y, (i + 1) / lPreviousStack.length, (i / previousStackSize) * maxPointerRadius);
	}
	for (let i = 0; i < rPreviousStack.length; i++) {
		let [x, y] = rPreviousStack[i];
		drawPointer(rctx, x, y, (i + 1) / rPreviousStack.length, (i / previousStackSize) * maxPointerRadius);
	}

	// Stick
	stick.style.left = `calc(${theme.stick.left - 8}% + ${stickx}px)`;
	stick.style.top = `calc(${theme.stick.top - 8}% + ${sticky}px)`;
	stick_click.style.visibility = dev.state.joystick.clicked ? "visible" : "hidden";

	// Trackpad clicks
	pads_rclick.style.visibility = dev.state.tpr.clicked ? "visible" : "hidden";
	pads_lclick.style.visibility = dev.state.tpl.clicked ? "visible" : "hidden";

	// ABXY Buttons
	buttons_a.style.visibility = dev.state.buttons.a ? "visible" : "hidden";
	buttons_b.style.visibility = dev.state.buttons.b ? "visible" : "hidden";
	buttons_x.style.visibility = dev.state.buttons.x ? "visible" : "hidden";
	buttons_y.style.visibility = dev.state.buttons.y ? "visible" : "hidden";

	// Triggers
	triggers_left.style.opacity = `calc(${dev.state.triggers.left.value / 2.5}%)`;
	triggers_right.style.opacity = `calc(${dev.state.triggers.right.value / 2.5}%)`;

	// Bumpers
	bumpers_left.style.visibility = dev.state.buttons.lb ? "visible" : "hidden";
	bumpers_right.style.visibility = dev.state.buttons.rb ? "visible" : "hidden";

	// Grips
	grips_left.style.visibility = dev.state.buttons.bl ? "visible" : "hidden";
	grips_right.style.visibility = dev.state.buttons.br ? "visible" : "hidden";

	// Steam, start, select
	system_select.style.visibility = dev.state.buttons.select ? "visible" : "hidden";
	system_steam.style.visibility = dev.state.buttons.steam ? "visible" : "hidden";
	system_start.style.visibility = dev.state.buttons.start ? "visible" : "hidden";

	// Refresh canvas
	window.requestAnimationFrame(refreshCanvas);
}

/**
 * Draw a pointer onto the given context
 *
 * @param {CanvasRenderingContext2D} ctx - A 2d context to render with
 * @param {int} x - x coordinate
 * @param {int} y - y coordinate
 * @param {float} o - a float between 0 and 1 for opacity
 * @param {int} r - the radius of the pointer
 */
function drawPointer(ctx, x, y, o = 1, r = 20) {
	ctx.beginPath();
	ctx.arc(x, y, r, 0, 2 * Math.PI, false);
	ctx.filter = `blur(6px)`;
	ctx.fillStyle = `rgba(0,202,239,255)`;
	ctx.fill();
	ctx.filter = "none";
	ctx.closePath();
}

refreshCanvas();
